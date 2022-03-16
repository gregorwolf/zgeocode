CLASS zcl_gis_route_yours DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_gis_route .
  PROTECTED SECTION.

    DATA positions TYPE geopositionstab .
    DATA gr_client TYPE REF TO if_http_client .
    DATA distance TYPE geodist .
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_gis_route_yours IMPLEMENTATION.


  METHOD if_gis_route~add_stop.
    APPEND position TO me->positions.
  ENDMETHOD.


  METHOD if_gis_route~execute.
    DATA: rows TYPE i.
    DATA: lat      TYPE string,
          lon      TYPE string,
          url      TYPE string,
          position LIKE LINE OF me->positions,
          dist_str TYPE string.

*   XML parser
    DATA:
      lv_xml           TYPE          xstring,
      lr_ixml          TYPE REF TO   if_ixml,
      lr_parser        TYPE REF TO   if_ixml_parser,
      lr_streamfactory TYPE REF TO   if_ixml_stream_factory,
      lr_istream       TYPE REF TO   if_ixml_istream,
      lr_document      TYPE REF TO   if_ixml_document,
      lr_distances     TYPE REF TO	  if_ixml_node_collection,
      lr_item          TYPE REF TO   if_ixml_node,
      lr_attributes    TYPE REF TO   if_ixml_named_node_map,
      lr_node          TYPE REF TO   if_ixml_node,
      lr_searchresults TYPE REF TO	  if_ixml_node_collection,
      lv_count         TYPE          i.
    FIELD-SYMBOLS:
      <lv_field>    TYPE          any,
      <lv_sequence> TYPE          string.


    DESCRIBE TABLE me->positions LINES rows.
    IF rows < 2.
      RAISE empty_route.
    ENDIF.

    LOOP AT me->positions INTO position.
      IF sy-tabix < rows.
        " From
        lat = position-latitude.
        CONDENSE lat.
        lon = position-longitude.
        CONDENSE lon.
        CONCATENATE 'http://www.yournavigation.org/api/1.0/gosmore.php?format=kml&flat='
        lat '&flon=' lon INTO url.
        " To
        READ TABLE me->positions INTO position INDEX sy-tabix + 1.
        lat = position-latitude.
        CONDENSE lat.
        lon = position-longitude.
        CONDENSE lon.
        CONCATENATE url '&tlat=' lat '&tlon=' lon
        '&v=motorcar&fast=1&layer=mapnik' INTO url.

        IF gr_client IS NOT BOUND.
          cl_http_client=>create_by_url(
            EXPORTING
              url           = url
            IMPORTING
              client        = gr_client
            EXCEPTIONS
              argument_not_found = 1
              plugin_not_active  = 2
              internal_error     = 3
              OTHERS             = 4
          ).
          IF sy-subrc <> 0.
            RAISE internal_error.
          ENDIF.
        ELSE.
          cl_http_utility=>set_request_uri(
            request = gr_client->request
            uri     = url
          ).
        ENDIF.

        gr_client->request->set_header_field(
          EXPORTING
            name  = 'X-Yours-client'   " Name of the header field
            value = 'https://cw.sdn.sap.com/cw/groups/zgeocode'   " HTTP header field value
        ).


        gr_client->send( EXCEPTIONS OTHERS = 1 ).
        IF sy-subrc <> 0.
          RAISE internal_error.
        ENDIF.
        gr_client->receive( EXCEPTIONS OTHERS = 1 ).
        IF sy-subrc <> 0.
          RAISE internal_error.
        ENDIF.

        lv_xml = gr_client->response->get_data( ).

        " Start XML parsing
        " Instanciate XML Parser
        lr_ixml = cl_ixml=>create( ).
        lr_streamfactory = lr_ixml->create_stream_factory( ).
        lr_istream = lr_streamfactory->create_istream_xstring( lv_xml ).
        lr_document = lr_ixml->create_document( ).
        lr_parser = lr_ixml->create_parser( stream_factory = lr_streamfactory
                                            istream        = lr_istream
                                            document       = lr_document ).
        lr_parser->parse( ).
        " Check if any results have been found
        lr_distances = lr_document->get_elements_by_tag_name( name = 'distance' ).
        lv_count = lr_distances->get_length( ).
        IF lv_count > 0.
          lr_item = lr_distances->get_item( 0 ).
          dist_str = lr_item->get_value( ).
          me->distance = me->distance + dist_str.
        ENDIF.
      ENDIF.
    ENDLOOP.
    " http://www.yournavigation.org/api/1.0/gosmore.php?
    " flat=48.057947090798&flon=12.569867451065&
    " tlat=47.952712196478&tlon=12.607888747491&v=motorcar&fast=1&layer=mapnik
  ENDMETHOD.


  METHOD if_gis_route~get_route_info.
    distance = me->distance.
  ENDMETHOD.


  METHOD if_gis_route~reset.
    CLEAR: me->positions.
  ENDMETHOD.
ENDCLASS.

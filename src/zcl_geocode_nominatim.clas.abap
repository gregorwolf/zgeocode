CLASS zcl_geocode_nominatim DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_geocoding_tool .

    CLASS-METHODS string_to_timestamp
      IMPORTING
        !timestamp_string TYPE string DEFAULT 'Sun, 14 Mar 10 20:34:15 +0000'
      RETURNING
        VALUE(timestamp)  TYPE timestamp .
  PROTECTED SECTION.

    DATA gr_client TYPE REF TO if_http_client .

    METHODS geocode_one_address
      IMPORTING
        !address             TYPE aes_addr
      EXPORTING
        !choice              TYPE geocd_choice_table
      CHANGING
        !container           TYPE aesc_tabs
        !result              TYPE geocd_ress
        !relevant_fields     TYPE geocd_addr_relfields_sortedtab
        !messages            TYPE aes_msg_table
        !corrected_addresses TYPE aes_addr_sortedtable .
    METHODS get_client
      IMPORTING
        !is_address       TYPE aes_addr
        !iv_servicenr     TYPE rfcdisplay-rfcsysid
        !iv_server        TYPE rfcdisplay-rfchost
        !iv_proxy         TYPE rfcdisplay-rfcgwhost
        !iv_proxy_service TYPE rfcdisplay-rfcgwserv
      RETURNING
        VALUE(rr_client)  TYPE REF TO if_http_client .
  PRIVATE SECTION.

    METHODS add_part
      IMPORTING
        !iv_url       TYPE string
        !iv_sep       TYPE string
        !iv_param     TYPE any
      RETURNING
        VALUE(rv_url) TYPE string .
ENDCLASS.



CLASS zcl_geocode_nominatim IMPLEMENTATION.


  METHOD add_part.
**********************************************************************
*& Add the supplied part to the url.
**********************************************************************
    DATA:
      lv_param  TYPE string.

    IF iv_param IS NOT INITIAL.
      lv_param = iv_param.
      lv_param = cl_http_utility=>escape_url( lv_param ).
      CONCATENATE iv_url iv_sep lv_param INTO rv_url.
    ELSE.
      rv_url = iv_url.
    ENDIF.
  ENDMETHOD.


  METHOD geocode_one_address.
**********************************************************************
*& Start geocoding the supplied address
**********************************************************************
    DATA:
*   HTTP client
      lv_servicenr     TYPE          rfcdisplay-rfcsysid,
      lv_server        TYPE          rfcdisplay-rfchost,
      lv_proxy_host    TYPE          rfcdisplay-rfcgwhost,
      lv_proxy_service TYPE          rfcdisplay-rfcgwserv,
      lr_client        TYPE REF TO   if_http_client,
*   General
      lv_dummy         TYPE          string,
      lv_timestamp     TYPE          string,
      ls_geocoding     TYPE          geocoding,
*   Access sequence
      ls_address       TYPE          aes_addr,
      lt_sequence      TYPE          string_table,
*   XML parser
      lv_xml           TYPE          xstring,
      lr_ixml          TYPE REF TO   if_ixml,
      lr_parser        TYPE REF TO   if_ixml_parser,
      lr_streamfactory TYPE REF TO   if_ixml_stream_factory,
      lr_istream       TYPE REF TO   if_ixml_istream,
      lr_document      TYPE REF TO   if_ixml_document,
      lr_place         TYPE REF TO    if_ixml_node_collection,
      lr_item          TYPE REF TO   if_ixml_node,
      lr_attributes    TYPE REF TO   if_ixml_named_node_map,
      lr_node          TYPE REF TO   if_ixml_node,
      lr_searchresults TYPE REF TO    if_ixml_node_collection,
      lv_count         TYPE          i.
    FIELD-SYMBOLS:
      <lv_field>    TYPE          any,
      <lv_sequence> TYPE          string.

* Build access sequence
    APPEND 'HOUSE_NUM2' TO lt_sequence.
    APPEND 'HOUSE_NUM1' TO lt_sequence.
    APPEND 'STREET'     TO lt_sequence.
    APPEND 'CITY2'      TO lt_sequence.
    APPEND 'CITY1'      TO lt_sequence.
    " For the Inside Track Netherlands
    APPEND 'POST_CODE1' TO lt_sequence.
* If we got no country we should not be geocoding...

    CALL FUNCTION 'RFC_READ_HTTP_DESTINATION'
      EXPORTING
        destination             = 'ZGEOCODE_NOMINATIM'
      IMPORTING
        servicenr               = lv_servicenr
        server                  = lv_server
        proxy_host              = lv_proxy_host
        proxy_service           = lv_proxy_service
      EXCEPTIONS
        authority_not_available = 1
        destination_not_exist   = 2
        information_failure     = 3
        internal_failure        = 4
        no_http_destination     = 5.
    " Fallback to Quickstart without maintaining a HTTP Destination
    IF sy-subrc = 2.
      lv_servicenr = '443'.
      lv_server    = 'nominatim.openstreetmap.org'.
    ELSE.
      CHECK sy-subrc = 0.
    ENDIF.

    ls_address = address.
    " Inside Track NL #sitNL
    " CLEAR ls_address-address-post_code1.

    LOOP AT lt_sequence ASSIGNING <lv_sequence>.
      lr_client = me->get_client( is_address        = ls_address
                                  iv_servicenr      = lv_servicenr
                                  iv_server         = lv_server
                                  iv_proxy          = lv_proxy_host
                                  iv_proxy_service  = lv_proxy_service ).

      lr_client->send(
        EXCEPTIONS
          http_communication_failure = 1              "     Communication Error
          http_invalid_state         = 2              "     Invalid state
          http_processing_failed     = 3              "     Error when processing method
          http_invalid_timeout       = 4              "     Invalid Time Entry
          OTHERS                     = 5
      ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO DATA(message).
        EXIT.
      ENDIF.

      lr_client->receive(
        EXCEPTIONS
          http_communication_failure = 1 " Communication Error
          http_invalid_state         = 2 " Invalid state
          http_processing_failed     = 3 " Error when processing method
          OTHERS                     = 4
      ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO message.
        EXIT.
      ENDIF.

      lv_xml = lr_client->response->get_data( ).

*   Start XML parsing
*   Instanciate XML Parser
      lr_ixml = cl_ixml=>create( ).
      lr_streamfactory = lr_ixml->create_stream_factory( ).
      lr_istream = lr_streamfactory->create_istream_xstring( lv_xml ).
      lr_document = lr_ixml->create_document( ).
      lr_parser = lr_ixml->create_parser( stream_factory = lr_streamfactory
                                          istream        = lr_istream
                                          document       = lr_document ).
      lr_parser->parse( ).

*   Check if any results have been found
      lr_place = lr_document->get_elements_by_tag_name( name = 'place' ).
      lv_count = lr_place->get_length( ).
      IF lv_count > 0.
*     Get lon/lat from XML
        lr_item = lr_place->get_item( 0 ).
        lr_attributes = lr_item->get_attributes( ).
        lr_node = lr_attributes->get_named_item( 'lat' ).
        lv_dummy = lr_node->get_value( ).
        ls_geocoding-latitude = lv_dummy.
        lr_node = lr_attributes->get_named_item( 'lon' ).
        lv_dummy = lr_node->get_value( ).
        ls_geocoding-longitude = lv_dummy.

*     Get Timestamp
        lr_searchresults = lr_document->get_elements_by_tag_name( name = 'searchresults' ).
        lr_item = lr_searchresults->get_item( 0 ).
        lr_attributes = lr_item->get_attributes( ).
        lr_node = lr_attributes->get_named_item( 'timestamp' ).
        lv_timestamp = lr_node->get_value( ).
        CALL METHOD zcl_geocode_nominatim=>string_to_timestamp
          EXPORTING
            timestamp_string = lv_timestamp
          RECEIVING
            timestamp        = ls_geocoding-srctstmp.

        ls_geocoding-srcid = 'ZNOM'.
        IF lv_count = 1.
          ls_geocoding-precisid = '0600'. "Detail: Region-Level
        ELSE.
          ls_geocoding-precisid = '0500'. "Detail: Region-Level
        ENDIF.
        zcl_geocode_helper=>move_data_to_aescontainer(
          EXPORTING
            geocoding = ls_geocoding
          CHANGING
            aesc      = container-container
        ).
        result-id = ls_address-id.
        result-res = 0. "Everything's fine
*     end the loop
        EXIT.
      ELSE.
*     Adjust address for next iteration
        ASSIGN COMPONENT <lv_sequence> OF STRUCTURE ls_address-address TO <lv_field>.
        IF sy-subrc = 0.
          CLEAR <lv_field>.
        ENDIF.
      ENDIF.
    ENDLOOP.
    IF lv_count = 0.
      result-id = address-id.
      result-res = 6.
    ENDIF.
  ENDMETHOD.


  METHOD get_client.
    DATA:
      lv_proxy   TYPE            string,
      lv_proxy_s TYPE            string,
      lv_url     TYPE            string,
      lv_enc     TYPE            string,
      country    TYPE            string.

    CONCATENATE 'https://' iv_server '/search.php?format=xml&iv_sepaddressdetails=1' INTO lv_url.


    SELECT SINGLE landx50 FROM t005t INTO country
      WHERE spras = 'E'
        AND land1 = is_address-address-country.

* Trostberger%20Str.%20128Tacherting&


    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-street && | | && is_address-address-house_num1    iv_sep = 'street=' ).
    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-city1      iv_sep = '&city=').
    lv_url = add_part( iv_url = lv_url iv_param = country    iv_sep = '&country=' ).
    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-post_code1 iv_sep = '&postalcode=' ).
*  lv_url = add_part( iv_url = lv_url iv_param = is_address-address-city2      iv_sep = '/').
*  lv_url = add_part( iv_url = lv_url iv_param = is_address-address-house_num1 iv_sep = '%20' ).
*  lv_url = add_part( iv_url = lv_url iv_param = is_address-address-house_num2 iv_sep = '%20' ).
    CONDENSE lv_url.

    lv_proxy = iv_proxy.
    lv_proxy_s = iv_proxy_service.

    " Contributed by Markus Reich http://www.markusreich.at
    " Use a global attribute for the HTTP Client avoiding
    " memory problems in batch geocoding
    IF gr_client IS NOT BOUND.
      cl_http_client=>create_by_url(
        EXPORTING
          url           = lv_url
          proxy_host    = lv_proxy
          proxy_service = lv_proxy_s
        IMPORTING
          client        = rr_client
        EXCEPTIONS
          argument_not_found = 1
          plugin_not_active  = 2
          internal_error     = 3
          OTHERS             = 4 ).
      gr_client = rr_client.
    ELSE.
      rr_client = gr_client.
      cl_http_utility=>set_request_uri(
        request = rr_client->request
        uri     = lv_url ).
    ENDIF.
  ENDMETHOD.


  METHOD if_geocoding_tool~geocode.
**********************************************************************
*& Method called by framework. Entry point for the geocoding.
**********************************************************************
    " This default coding is borrowed from the CL_GEOCODER_SAP0
    " GEOCODE method
    DATA:
      lv_msg             TYPE string,
      ls_geocd_ress      TYPE geocd_ress,
      ls_aesc_tabs       TYPE aesc_tabs,
      lt_geocd_choice    TYPE geocd_choice_table,
      lt_relevant_fields TYPE geocd_addr_relfields_sortedtab.
    FIELD-SYMBOLS:
      <ls_msg>      TYPE aes_msg,
      <ls_aes_addr> TYPE aes_addr.

    LOOP AT addresses ASSIGNING <ls_aes_addr>.
      CLEAR: lt_geocd_choice, ls_aesc_tabs, ls_geocd_ress.
*   create a result entry
      ls_geocd_ress-id = <ls_aes_addr>-id.
*   remove corrected addresses with given ID
      DELETE TABLE corrected_addresses WITH TABLE KEY id = <ls_aes_addr>-id.
*   read container for geocoding result
      READ TABLE containers INTO ls_aesc_tabs
        WITH TABLE KEY id = <ls_aes_addr>-id.
      IF sy-subrc <> 0.
*     Message container has to exist. Otherwise return error.
        MESSAGE ID 'GEOCODING' TYPE 'X' NUMBER '008' INTO lv_msg.
        APPEND INITIAL LINE TO messages ASSIGNING <ls_msg>.
        <ls_msg>-id = <ls_aes_addr>-id.
        <ls_msg>-order_no = 1.
        MOVE-CORRESPONDING sy TO <ls_msg>-message.
        RETURN.
      ENDIF.
      me->geocode_one_address(
        EXPORTING
          address             = <ls_aes_addr>
        IMPORTING
          choice              = lt_geocd_choice
        CHANGING
          container           = ls_aesc_tabs
          result              = ls_geocd_ress
          relevant_fields     = lt_relevant_fields
          messages            = messages
          corrected_addresses = corrected_addresses
      ).
      APPEND LINES OF lt_geocd_choice TO choice.
      APPEND ls_geocd_ress TO results.
      MODIFY TABLE containers FROM ls_aesc_tabs.
    ENDLOOP.
  ENDMETHOD.

  METHOD string_to_timestamp.
    DATA: day           TYPE char2,
          month         TYPE char3,
          month_names   TYPE TABLE OF t247,
          month_name    LIKE LINE OF month_names,
          language      TYPE langu VALUE 'E',
          year          TYPE char2,
          time_string   TYPE string,
          time          TYPE uzeit,
          timestamp_tmp TYPE string.
    day = timestamp_string+5(2).
    month = timestamp_string+8(3).
    year = timestamp_string+12(2).
    time_string = timestamp_string+15(8).
    REPLACE ALL OCCURRENCES OF ':' IN time_string WITH ''.
    WRITE time_string TO time.
    CALL FUNCTION 'MONTH_NAMES_GET'
      EXPORTING
        language    = language
      TABLES
        month_names = month_names.
    READ TABLE month_names INTO month_name
      WITH KEY ktx = month.
    CONCATENATE '20' year month_name-mnr day time INTO timestamp_tmp.
    timestamp = timestamp_tmp.
  ENDMETHOD.
ENDCLASS.

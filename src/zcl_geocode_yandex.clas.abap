CLASS zcl_geocode_yandex DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_geocoding_tool .
    INTERFACES zif_geocode_yandex_const .

    CLASS-METHODS string_to_timestamp
      IMPORTING
        !timestamp_string TYPE string DEFAULT 'Sun, 14 Mar 10 20:34:15 +0000'
      RETURNING
        VALUE(timestamp)  TYPE timestamp .
  PROTECTED SECTION.

    TYPES:
      BEGIN OF ms_geocoder_rfc_destination,
        srcid           TYPE geosrcid,
        funcname        TYPE funcname,
        rfc_destination TYPE rfcdest,
      END OF ms_geocoder_rfc_destination .

    CLASS-DATA:
      m_buffer_rfc_destinations
      TYPE SORTED TABLE OF ms_geocoder_rfc_destination
      WITH UNIQUE KEY srcid .

    METHODS get_rfc_function
      IMPORTING
        !srcid           TYPE geosrcid
      EXPORTING
        !funcname        TYPE funcname
        !rfc_destination TYPE rfcdest .
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
    METHODS move_data_to_aescontainer
      IMPORTING
        !geocoding TYPE geocoding
      CHANGING
        !aesc      TYPE aesc .
    METHODS move_field_to_aescontainer
      IMPORTING
        !field TYPE fieldname
        !value TYPE char255
      CHANGING
        !aesc  TYPE aesc .
    METHODS get_country
      IMPORTING
        !is_address      TYPE adrc_struc
        !i_spras         TYPE spras OPTIONAL
        !is_info         TYPE geocdxinfo OPTIONAL
      RETURNING
        VALUE(e_country) TYPE string .
    METHODS get_region
      IMPORTING
        !i_spras        TYPE spras DEFAULT sy-langu
        !is_address     TYPE adrc_struc
        !is_info        TYPE geocdxinfo OPTIONAL
      RETURNING
        VALUE(e_region) TYPE string .
    METHODS find_by_path_recursive
      IMPORTING
        !ir_node        TYPE REF TO if_ixml_node
        !iv_path        TYPE string
      RETURNING
        VALUE(rv_value) TYPE string .
  PRIVATE SECTION.

    ALIASES gc_airport
      FOR zif_geocode_yandex_const~gc_airport .
    ALIASES gc_area
      FOR zif_geocode_yandex_const~gc_area .
    ALIASES gc_country
      FOR zif_geocode_yandex_const~gc_country .
    ALIASES gc_district
      FOR zif_geocode_yandex_const~gc_district .
    ALIASES gc_exact
      FOR zif_geocode_yandex_const~gc_exact .
    ALIASES gc_house
      FOR zif_geocode_yandex_const~gc_house .
    ALIASES gc_hydro
      FOR zif_geocode_yandex_const~gc_hydro .
    ALIASES gc_locality
      FOR zif_geocode_yandex_const~gc_locality .
    ALIASES gc_metro
      FOR zif_geocode_yandex_const~gc_metro .
    ALIASES gc_near
      FOR zif_geocode_yandex_const~gc_near .
    ALIASES gc_number
      FOR zif_geocode_yandex_const~gc_number .
    ALIASES gc_other
      FOR zif_geocode_yandex_const~gc_other .
    ALIASES gc_province
      FOR zif_geocode_yandex_const~gc_province .
    ALIASES gc_railway
      FOR zif_geocode_yandex_const~gc_railway .
    ALIASES gc_range
      FOR zif_geocode_yandex_const~gc_range .
    ALIASES gc_route
      FOR zif_geocode_yandex_const~gc_route .
    ALIASES gc_street
      FOR zif_geocode_yandex_const~gc_street .
    ALIASES gc_vegetation
      FOR zif_geocode_yandex_const~gc_vegetation .

    DATA gv_xinfo TYPE geocdxinfo .

    METHODS add_part
      IMPORTING
        !iv_url       TYPE string
        !iv_sep       TYPE string OPTIONAL
        !iv_param     TYPE any
      RETURNING
        VALUE(rv_url) TYPE string .
ENDCLASS.



CLASS zcl_geocode_yandex IMPLEMENTATION.


  METHOD add_part.
**********************************************************************
*& Add the supplied part to the url.
**********************************************************************
    DATA:
      lv_param  TYPE string.

    rv_url = iv_url.

    IF iv_param IS NOT INITIAL.
      lv_param = iv_param.
      lv_param = cl_http_utility=>escape_url( lv_param ).
      IF iv_sep IS NOT INITIAL.
        CONCATENATE rv_url iv_sep INTO rv_url.
      ENDIF.
      CONCATENATE rv_url lv_param INTO rv_url.
    ENDIF.
  ENDMETHOD.                    "ADD_PART


  METHOD find_by_path_recursive.

    DATA: lr_node   TYPE REF TO if_ixml_node,
          lr_item   TYPE REF TO if_ixml_node,
          lr_list   TYPE REF TO if_ixml_node_list,
          lv_name   TYPE string,
          lv_path   TYPE string,
          lv_length TYPE i,
          ind       TYPE i.

    CHECK ir_node IS BOUND.
    lr_node = ir_node.
    lr_list = lr_node->get_children( ).
    lv_length = lr_list->get_length( ).
    WHILE ind <= lv_length AND rv_value IS INITIAL.
      lr_item = lr_list->get_item( ind ).

      SPLIT iv_path AT '\' INTO lv_name lv_path.
      IF lv_name EQ lr_item->get_name( ).
        IF lv_path IS NOT INITIAL.
          rv_value = find_by_path_recursive( ir_node = lr_item iv_path = lv_path ).
        ELSE.
          rv_value = lr_item->get_value( ).
        ENDIF.
      ELSE.
        ADD 1 TO ind.
      ENDIF.
    ENDWHILE.


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
      lv_response_data TYPE          xstring,
      lr_ixml          TYPE REF TO   if_ixml,
      lr_parser        TYPE REF TO   if_ixml_parser,
      lr_streamfactory TYPE REF TO   if_ixml_stream_factory,
      lr_istream       TYPE REF TO   if_ixml_istream,
      lr_document      TYPE REF TO   if_ixml_document,
      lr_place         TYPE REF TO	  if_ixml_node_collection,
      lr_iterator      TYPE REF TO   if_ixml_node_iterator,
      lr_item          TYPE REF TO   if_ixml_node,
      lv_kind          TYPE string,
      lv_precision     TYPE string,
      lv_pos           TYPE string,
      lv_longitude     TYPE string,
      lv_latitude      TYPE string,
      lv_count         TYPE i,
      lv_destination   TYPE rfcdest.

    DATA: lf_test       TYPE abap_bool.
    FIELD-SYMBOLS:
      <lv_field>    TYPE          any,
      <lv_sequence> TYPE          string.

    CONSTANTS: lc_yandex_default TYPE rfcdest VALUE 'ZGEOCODE_YANDEX'.

* If we got no country we should not be geocoding...

    CALL METHOD me->get_rfc_function
      EXPORTING
        srcid           = gv_xinfo-srcid
      IMPORTING
        rfc_destination = lv_destination.

    IF lv_destination IS INITIAL.
      lv_destination = lc_yandex_default.
    ENDIF.

    CALL FUNCTION 'RFC_READ_HTTP_DESTINATION'
      EXPORTING
        destination             = lv_destination
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
      lv_servicenr = '80'.
      lv_server    = 'geocode-maps.yandex.ru'.
    ELSE.
      CHECK sy-subrc = 0.
    ENDIF.

    ls_address = address.

    lr_client = me->get_client( is_address        = ls_address
                                iv_servicenr      = lv_servicenr
                                iv_server         = lv_server
                                iv_proxy          = lv_proxy_host
                                iv_proxy_service  = lv_proxy_service ).

    lr_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      EXIT.
    ENDIF.
    lr_client->receive( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      EXIT.
    ENDIF.

    lv_response_data = lr_client->response->get_data( ).
    lr_client->close( ).
    IF lf_test EQ 'X'.
* For test
      DATA: lv_test_string TYPE string.
      CALL FUNCTION 'CRM_IC_XML_XSTRING2STRING'
        EXPORTING
          inxstring = lv_response_data
        IMPORTING
          outstring = lv_test_string.
    ENDIF.
*   Start XML parsing
*   Instanciate XML Parser
    lr_ixml = cl_ixml=>create( ).
    lr_streamfactory = lr_ixml->create_stream_factory( ).
    lr_istream = lr_streamfactory->create_istream_xstring( lv_response_data ).
    lr_document = lr_ixml->create_document( ).
    lr_parser = lr_ixml->create_parser( stream_factory = lr_streamfactory
                                        istream        = lr_istream
                                        document       = lr_document ).
    lr_parser->parse( ).

*   Check if any results have been found
    lr_place = lr_document->get_elements_by_tag_name( name = 'featureMember' ).
    lv_count = lr_place->get_length( ).
    IF lv_count > 0.
*     Get lon/lat from XML
      lr_iterator = lr_place->create_iterator( ).
      lr_item = lr_iterator->get_next( ).

      WHILE lr_item IS BOUND.
        lv_kind = find_by_path_recursive( ir_node = lr_item iv_path = 'GeoObject\metaDataProperty\GeocoderMetaData\kind' ).
        lv_precision = find_by_path_recursive( ir_node = lr_item iv_path = 'GeoObject\metaDataProperty\GeocoderMetaData\precision' ).
        lv_pos = find_by_path_recursive( ir_node = lr_item iv_path = 'GeoObject\Point\pos' ).

        IF lv_pos IS NOT INITIAL.
          SPLIT lv_pos AT space INTO lv_longitude lv_latitude.
          ls_geocoding-longitude = lv_longitude.
          ls_geocoding-latitude = lv_latitude.
          CASE lv_precision.
            WHEN gc_exact.
              ls_geocoding-precisid = '1300'. "House number with supplement (e.g. Neurottstr. 7b)
            WHEN gc_number.
              ls_geocoding-precisid = '1200'. "House number (exact)
            WHEN gc_near.
              ls_geocoding-precisid = '1100'. "House number (interpolated)
            WHEN gc_range.
              ls_geocoding-precisid = '1000'. "House number range (street section) mid-point
            WHEN gc_street.
              ls_geocoding-precisid = '0900'. "Street mid-point
            WHEN gc_other.
              CASE lv_kind.
                WHEN gc_house.
                  ls_geocoding-precisid = '1200'. "House number (exact)
                WHEN gc_street.
                  ls_geocoding-precisid = '0900'. "Street mid-point
                WHEN gc_metro.
                  ls_geocoding-precisid = '0850'. "Metro /self-defined/
                WHEN gc_district.
                  ls_geocoding-precisid = '0800'. "District
                WHEN gc_locality.
                  ls_geocoding-precisid = '0700'. "City
                WHEN gc_area.
                  ls_geocoding-precisid = '0500'. "Town limits
                WHEN gc_province.
                  ls_geocoding-precisid = '0400'. "Region
                WHEN gc_country.
                  ls_geocoding-precisid = '0300'. "Coutnry
                WHEN gc_hydro
                  OR gc_railway
                  OR gc_route
                  OR gc_vegetation
                  OR gc_airport
                  OR gc_other.
                  ls_geocoding-precisid = '0000'. "Other
                WHEN OTHERS.
                  ls_geocoding-precisid = '0000'. "Other
              ENDCASE.
            WHEN OTHERS.
          ENDCASE.

          GET TIME STAMP FIELD ls_geocoding-srctstmp.

          ls_geocoding-srcid = gv_xinfo-srcid.

          CALL METHOD move_data_to_aescontainer
            EXPORTING
              geocoding = ls_geocoding
            CHANGING
              aesc      = container-container.

          result-id = ls_address-id.
          result-res = 0. "Everything's fine
        ENDIF.
        lr_item = lr_iterator->get_next( ).
      ENDWHILE.

    ENDIF.

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
      lv_enc     TYPE            string.


*  CONCATENATE 'http://' iv_server '/1.x/?format=json&geocode=' INTO lv_url.
    CONCATENATE 'http://' iv_server '/1.x/?geocode=' INTO lv_url.


    lv_url = add_part( iv_url = lv_url iv_param = get_country( is_address-address ) ).
    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-city1 iv_sep = ',+').
    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-city2 iv_sep = ',+').
    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-street iv_sep = ',+' ).
    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-house_num1 iv_sep = ',+' ).
    lv_url = add_part( iv_url = lv_url iv_param = is_address-address-house_num2 iv_sep = ',+' ).

    CONDENSE lv_url.

    lv_proxy = iv_proxy.
    lv_proxy_s = iv_proxy_service.

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
  ENDMETHOD.


  METHOD get_country.

    DATA lv_country TYPE land1.
    DATA lv_landx TYPE landx.
    DATA lv_spras TYPE spras.

    IF is_address-country IS NOT INITIAL.
      lv_country = is_address-country.
    ELSE.
      lv_country = is_info-country.
    ENDIF.
    CHECK lv_country IS NOT INITIAL.

    IF is_info-language IS NOT INITIAL.
      lv_spras = is_info-language.
    ELSE.
      lv_spras = i_spras.
    ENDIF.

    CLEAR lv_landx.
    SELECT SINGLE landx landx50 FROM t005t INTO (lv_landx, e_country) WHERE land1 = lv_country
                                                    AND spras = lv_spras.
    IF e_country IS INITIAL AND lv_landx IS NOT INITIAL.
      e_country = lv_landx.
    ELSEIF sy-subrc NE 0.
      CLEAR e_country.
    ENDIF.

  ENDMETHOD.                    "GET_COUNTRY


  METHOD get_region.

    DATA l_country TYPE land1.

    IF is_address-country IS NOT INITIAL.
      l_country = is_address-country.
    ELSE.
      l_country = is_info-country.
    ENDIF.

    CHECK l_country IS NOT INITIAL AND is_address-region IS NOT INITIAL.

    SELECT SINGLE bezei FROM t005u INTO e_region WHERE spras = i_spras
                                                   AND land1 = is_address-country
                                                   AND bland = is_address-region.
    IF sy-subrc <> 0.
      CLEAR e_region.
    ENDIF.

  ENDMETHOD.


  METHOD get_rfc_function .
    DATA:
      lv_rfc_destination TYPE ms_geocoder_rfc_destination,
      lv_geocd2cls       TYPE geocd2cls.

* initialize result
    CLEAR rfc_destination.

* try to read from buffer
    READ TABLE m_buffer_rfc_destinations INTO lv_rfc_destination
      WITH TABLE KEY srcid = srcid.

    IF sy-subrc <> 0.
*   not in buffer yet, so read from db
      SELECT SINGLE * FROM geocd2cls INTO lv_geocd2cls
        WHERE srcid = srcid.
      IF sy-subrc <> 0.
*     Nothing found? Customizing error.
        EXIT.
      ENDIF.

*   insert new rfc_destination into buffer
      lv_rfc_destination-srcid = srcid.
      lv_rfc_destination-funcname = lv_geocd2cls-funcname.
      lv_rfc_destination-rfc_destination = lv_geocd2cls-rfc_dest.
      INSERT lv_rfc_destination INTO TABLE m_buffer_rfc_destinations.
    ENDIF.

* return result
    funcname        = lv_rfc_destination-funcname.
    rfc_destination = lv_rfc_destination-rfc_destination.

  ENDMETHOD.


  METHOD if_geocoding_tool~geocode.
**********************************************************************
*& Method called by framework. Entry point for the geocoding.
**********************************************************************

    DATA:
      lv_msg             TYPE string,
      ls_geocd_ress      TYPE geocd_ress,
      ls_aesc_tabs       TYPE aesc_tabs,
      lt_geocd_choice    TYPE geocd_choice_table,
      lt_relevant_fields TYPE geocd_addr_relfields_sortedtab.
    FIELD-SYMBOLS:
      <ls_msg>      TYPE aes_msg,
      <ls_aes_addr> TYPE aes_addr.

    gv_xinfo = xinfo.

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


  METHOD move_data_to_aescontainer.
    DATA:
      lv_aesc_struc TYPE aesc_struc,
      lv_value      TYPE char255.
    lv_value = geocoding-longitude.
    CALL METHOD move_field_to_aescontainer
      EXPORTING
        field = 'LONGITUDE'
        value = lv_value
      CHANGING
        aesc  = aesc.
    lv_value = geocoding-latitude.
    CALL METHOD move_field_to_aescontainer
      EXPORTING
        field = 'LATITUDE'
        value = lv_value
      CHANGING
        aesc  = aesc.
    lv_value = geocoding-altitude.
    CALL METHOD move_field_to_aescontainer
      EXPORTING
        field = 'ALTITUDE'
        value = lv_value
      CHANGING
        aesc  = aesc.
    lv_value = geocoding-srcid.
    CALL METHOD move_field_to_aescontainer
      EXPORTING
        field = 'SRCID'
        value = lv_value
      CHANGING
        aesc  = aesc.
    lv_value = geocoding-srctstmp.
    CALL METHOD move_field_to_aescontainer
      EXPORTING
        field = 'SRCTSTMP'
        value = lv_value
      CHANGING
        aesc  = aesc.
    lv_value = geocoding-precisid.
    CALL METHOD move_field_to_aescontainer
      EXPORTING
        field = 'PRECISID'
        value = lv_value
      CHANGING
        aesc  = aesc.
    lv_value = geocoding-tzone.
    CALL METHOD move_field_to_aescontainer
      EXPORTING
        field = 'TZONE'
        value = lv_value
      CHANGING
        aesc  = aesc.
  ENDMETHOD.


  METHOD move_field_to_aescontainer.
    DATA:
      lv_aesc_struc TYPE aesc_struc,
      lv_value      TYPE char255.
    lv_value = value. "remove spaces
    CONDENSE lv_value.
    READ TABLE aesc INTO lv_aesc_struc
      WITH KEY service = 'GEOCODING'
               field   = field.
    IF sy-subrc <> 0.
      lv_aesc_struc-service = 'GEOCODING'.
      lv_aesc_struc-field   = field.
      lv_aesc_struc-value   = lv_value.
      INSERT lv_aesc_struc INTO TABLE aesc.
    ELSE.
      lv_aesc_struc-value   = lv_value.
      MODIFY TABLE aesc FROM lv_aesc_struc TRANSPORTING value.
    ENDIF.
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

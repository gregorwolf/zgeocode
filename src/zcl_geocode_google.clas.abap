CLASS zcl_geocode_google DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_geocoding_tool .
  PROTECTED SECTION.
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
      RETURNING
        VALUE(rr_client) TYPE REF TO if_http_client .
  PRIVATE SECTION.
    METHODS add_part
      IMPORTING
        !iv_url       TYPE string
        !iv_sep       TYPE string
        !iv_param     TYPE any
      RETURNING
        VALUE(rv_url) TYPE string.
ENDCLASS.


CLASS zcl_geocode_google IMPLEMENTATION.

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
    DATA: lv_path      TYPE string VALUE '/maps/api/geocode/json?',
          apikey       TYPE string,
          country      TYPE string,
          ls_response  TYPE zgeocode_google_response,
          ls_geocoding TYPE geocoding.

    SELECT SINGLE landx50 FROM t005t INTO country
    WHERE spras = 'E'
      AND land1 = address-address-country.

    lv_path = add_part( iv_url = lv_path iv_param = address-address-street && | | && address-address-house_num1 && | | iv_sep = 'address=' ).
    lv_path = add_part( iv_url = lv_path iv_param = address-address-post_code1 iv_sep = ' ' ).
    lv_path = add_part( iv_url = lv_path iv_param = address-address-city1      iv_sep = ' ').
    lv_path = add_part( iv_url = lv_path iv_param = country    iv_sep = ' ' ).

    SELECT SINGLE infostring FROM geocd2cls INTO apikey WHERE srcid = 'ZGOO'.
    lv_path = lv_path && '&key=' && apikey.

    DATA(client) = me->get_client( ).
    client->request->set_header_field(
        name  = if_http_header_fields_sap=>request_uri
        value = lv_path
    ).

    client->send(
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

    client->receive(
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
    DATA(lv_json) = client->response->get_cdata( ).

    /ui2/cl_json=>deserialize(
      EXPORTING
        json          = lv_json
        pretty_name   = abap_true
      CHANGING
        data          = ls_response ).

    DATA(lv_lines) = lines( ls_response-results ).

    IF lv_lines > 0.
      READ TABLE ls_response-results ASSIGNING FIELD-SYMBOL(<fs_result>) INDEX 1.
      ls_geocoding-latitude = <fs_result>-geometry-location-lat.
      ls_geocoding-longitude = <fs_result>-geometry-location-lng.
      ls_geocoding-srcid = 'ZGOO'.
      ls_geocoding-precisid = '0500'. "Detail: Region-Level
      zcl_geocode_helper=>move_data_to_aescontainer(
        EXPORTING
          geocoding = ls_geocoding
        CHANGING
          aesc      = container-container
      ).
      result-res = 0. "Everything's fine
    ENDIF.

  ENDMETHOD.


  METHOD get_client.
    CONSTANTS: geocoding_destination TYPE rfcdest VALUE 'ZGEOCODE_GOOGLE'.
    DATA:
      lv_servicenr TYPE          rfcdisplay-rfcsysid,
      lv_server    TYPE          rfcdisplay-rfchost.

    " Check if geocoding destination exists
    CALL FUNCTION 'RFC_READ_HTTP_DESTINATION'
      EXPORTING
        destination             = geocoding_destination
      IMPORTING
        servicenr               = lv_servicenr
        server                  = lv_server
      EXCEPTIONS
        authority_not_available = 1
        destination_not_exist   = 2
        information_failure     = 3
        internal_failure        = 4
        no_http_destination     = 5.

    IF sy-subrc = 0.
      cl_http_client=>create_by_destination(
        EXPORTING
          destination              = geocoding_destination
        IMPORTING
          client                   = rr_client      " HTTP Client Abstraction
        EXCEPTIONS
          argument_not_found       = 1           " Connection Parameter (Destination) Not Available
          destination_not_found    = 2           " Destination not found
          destination_no_authority = 3           " No Authorization to Use HTTP Destination
          plugin_not_active        = 4           " HTTP/HTTPS Communication Not Available
          internal_error           = 5           " Internal Error (e.g. name too long)
          OTHERS                   = 6
      ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
    ELSE.
      " Fallback to default URL
      cl_http_client=>create_by_url(
        EXPORTING
          url                = 'https://maps.googleapis.com'
        IMPORTING
          client             = rr_client        " HTTP Client Abstraction
        EXCEPTIONS
          argument_not_found = 1             " Communication Parameters (Host or Service) Not Available
          plugin_not_active  = 2             " HTTP/HTTPS Communication Not Available
          internal_error     = 3             " Internal Error (e.g. name too long)
          OTHERS             = 4
      ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD if_geocoding_tool~geocode.
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
ENDCLASS.

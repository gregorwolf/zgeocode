*&---------------------------------------------------------------------*
*& Report  ZGEOCODE_NOMINATIM_TEST
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT  zgeocode_nominatim_test.

DATA: geocoder TYPE REF TO zcl_geocode_nominatim.

DATA: addresses	          TYPE aes_addr_table,
      address             TYPE aes_addr,
      xinfo	              TYPE geocdxinfo,
      options	            TYPE geocd_option,
      results	            TYPE geocd_res_table,
      choice              TYPE geocd_choice_table,
      relevant_fields	    TYPE geocd_addr_relfields_sortedtab,
      corrected_addresses	TYPE aes_addr_sortedtable,
      messages            TYPE aes_msg_table,
      containers          TYPE aesc_sortedtable,
      container           TYPE aesc_tabs,
      geocoding_container TYPE aesc_struc.

CALL FUNCTION 'GUID_CREATE'
  IMPORTING
    ev_guid_16 = address-id.

address-address-city1 = 'Tacherting'.
address-address-post_code1 = '83342'.
address-address-street = 'Trostberger Str.'.
address-address-house_num1 = '128'.
address-address-country = 'DE'.
address-address-time_zone = 'CET'.
address-address-langu_crea = 'EN'.
APPEND address TO addresses.

xinfo-country  = address-address-country.
xinfo-srcid	   = 'ZNOM'.
xinfo-language = 'EN'.

container-id = address-id.
APPEND container TO containers.

CREATE OBJECT geocoder.

geocoder->if_geocoding_tool~geocode(
  EXPORTING
    addresses           = addresses    " Addresses That Are To Be Geocoded
    xinfo               = xinfo    " Additional Information for the Geocoder
*    options             = options    " Geocoding: Options (IGS)
  IMPORTING
    results             = results    " Geocoding Results (per Address)
*    choice              = choice    " Address Selection List
*    relevant_fields     = relevant_fields    " Table of All Fields Relevant for Display in Geocoding
  CHANGING
    corrected_addresses = corrected_addresses    " Addresses Corrected By Geocoding Tool
    messages            = messages    " Messages Created by Geocoder
    containers          = containers    " Structure for Container with Number (Central Address Mgmt)
  EXCEPTIONS
    OTHERS              = 1
).

IF sy-subrc = 0 AND messages IS INITIAL.
  WRITE: / 'Geocoding result: '.
  LOOP AT containers INTO container.
    LOOP AT container-container INTO geocoding_container.
      WRITE: /
        geocoding_container-field(20),
        geocoding_container-service(20),
        geocoding_container-value(20).
    ENDLOOP.
  ENDLOOP.
ELSE.
  WRITE: / 'Some problem occured'.
ENDIF.


CLASS zcl_geocode_google_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
.
*?﻿<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
*?<asx:values>
*?<TESTCLASS_OPTIONS>
*?<TEST_CLASS>zcl_Geocode_google_Test
*?</TEST_CLASS>
*?<TEST_MEMBER>f_Cut
*?</TEST_MEMBER>
*?<OBJECT_UNDER_TEST>zcl_Geocode_google
*?</OBJECT_UNDER_TEST>
*?<OBJECT_IS_LOCAL/>
*?<GENERATE_FIXTURE>X
*?</GENERATE_FIXTURE>
*?<GENERATE_CLASS_FIXTURE/>
*?<GENERATE_INVOCATION>X
*?</GENERATE_INVOCATION>
*?<GENERATE_ASSERT_EQUAL/>
*?</TESTCLASS_OPTIONS>
*?</asx:values>
*?</asx:abap>
  PRIVATE SECTION.
    DATA:
      f_cut TYPE REF TO zcl_geocode_google.  "class under test

    METHODS: setup.
    METHODS: teardown.
    METHODS: geocode FOR TESTING.
ENDCLASS.       "zcl_Geocode_google_Test


CLASS zcl_geocode_google_test IMPLEMENTATION.

  METHOD setup.


    CREATE OBJECT f_cut.
  ENDMETHOD.


  METHOD teardown.



  ENDMETHOD.


  METHOD geocode.

    DATA: addresses TYPE aes_addr_table,
          address   TYPE aes_addr.
    DATA xinfo TYPE geocdxinfo.
    DATA options TYPE geocd_option.
    DATA results TYPE geocd_res_table.
    DATA choice TYPE geocd_choice_table.
    DATA relevant_fields TYPE geocd_addr_relfields_sortedtab.
    DATA corrected_addresses TYPE aes_addr_sortedtable.
    DATA messages TYPE aes_msg_table.
    DATA: containers TYPE aesc_sortedtable,
          container  TYPE aesc_tabs.

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
    xinfo-srcid    = 'ZGOO'.
    xinfo-language = 'EN'.

    container-id = address-id.
    APPEND container TO containers.

    f_cut->if_geocoding_tool~geocode(
      EXPORTING
        addresses = addresses
        xinfo = xinfo
*       OPTIONS = options
     IMPORTING
       results = results
*       CHOICE = choice
*       RELEVANT_FIELDS = relevant_Fields
      CHANGING
        corrected_addresses = corrected_addresses
        messages = messages
        containers = containers ).
  ENDMETHOD.




ENDCLASS.

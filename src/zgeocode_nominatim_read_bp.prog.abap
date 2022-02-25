*&---------------------------------------------------------------------*
*& Report  ZGEOCODE_NOMINATIM_READ_BP
*&
*&---------------------------------------------------------------------*
*& Created by Gregor Wolf
*&
*&---------------------------------------------------------------------*

REPORT  zgeocode_nominatim_read_bp.

DATA: gr_container TYPE REF TO cl_gui_custom_container,
      gr_viewer    TYPE REF TO cl_gui_html_viewer,
      gv_currurl   TYPE char1024.

DATA: bp TYPE bu_partner.
DATA: address_search TYPE bapibus1006_addr_search,
      central_search TYPE bapibus1006_central_search.
DATA: searchresult TYPE TABLE OF bapibus1006_bp_addr,
      return TYPE TABLE OF bapiret2.
DATA: geodata TYPE geocoding.
DATA: centraldata             TYPE bapibus1006_central,
      centraldataperson       TYPE bapibus1006_central_person,
      centraldataorganization TYPE bapibus1006_central_organ.
DATA: dist_int TYPE i.
DATA: addressdata TYPE bapibus1006_address.

FIELD-SYMBOLS: <searchresult_line> LIKE LINE OF searchresult.

PARAMETERS: bpsearch TYPE bu_partner DEFAULT '*',
            name1    TYPE bu_mcname1,
            name2    TYPE bu_mcname2,
            street   TYPE ad_mc_strt,
            house_no TYPE ad_hsnm1,
            postlcd  TYPE ad_pstcd1,
            city     TYPE ad_mc_city,
            region   TYPE regio,
            country  TYPE intca,
            nearby   TYPE flag,
            distance TYPE geodist DEFAULT 20000.

START-OF-SELECTION.

  address_search-street     = street.
  address_search-house_no   = house_no.
  address_search-postl_cod1 = postlcd.
  address_search-city1      = city.
  address_search-region     = region.
  address_search-countryiso = country.

  central_search-partner  = bpsearch.
  central_search-mc_name1 = name1.
  central_search-mc_name2 = name2.

  CALL FUNCTION 'BAPI_BUPA_SEARCH_2'
    EXPORTING
*   TELEPHONE                         = TELEPHONE
*   EMAIL                             = EMAIL
*   URL                               = URL
      addressdata                       = address_search
      centraldata                       = central_search
*   BUSINESSPARTNERROLECATEGORY       = BUSINESSPARTNERROLECATEGORY
*   ALL_BUSINESSPARTNERROLES          = ALL_BUSINESSPARTNERROLES
*   BUSINESSPARTNERROLE               = BUSINESSPARTNERROLE
*   COUNTRY_FOR_TELEPHONE             = COUNTRY_FOR_TELEPHONE
*   FAX_DATA                          = FAX_DATA
*   VALID_DATE                        = VALID_DATE
*   OTHERS                            = OTHERS
    TABLES
      searchresult                      = searchresult
      return                            = return.

  LOOP AT searchresult ASSIGNING <searchresult_line>.
    bp = <searchresult_line>-partner.
    CALL FUNCTION 'BAPI_BUPA_CENTRAL_GETDETAIL'
      EXPORTING
        businesspartner         = <searchresult_line>-partner
      IMPORTING
        centraldata             = centraldata
        centraldataperson       = centraldataperson
        centraldataorganization = centraldataorganization.

    CALL FUNCTION 'BAPI_BUPA_ADDRESS_GETDETAIL'
      EXPORTING
        businesspartner = <searchresult_line>-partner
      IMPORTING
        addressdata     = addressdata.

    geodata = zcl_geocode_helper=>get_geodata_for_bp( <searchresult_line>-partner ).
    FORMAT HOTSPOT ON.
    WRITE: / <searchresult_line>-partner. HIDE bp.
    FORMAT HOTSPOT OFF.
    IF NOT centraldataperson IS INITIAL.
      WRITE: centraldataperson-firstname(15), centraldataperson-lastname(15).
    ELSE.
      WRITE: centraldataorganization-name1(20), centraldataorganization-name2(10).
    ENDIF.
    WRITE: addressdata-street(25), addressdata-house_no, addressdata-postl_cod1, addressdata-city(25).
    WRITE: geodata-longitude, geodata-latitude.
  ENDLOOP.

AT LINE-SELECTION.
  DATA: parameters TYPE tihttpnvp,
        parameter  LIKE LINE OF parameters,
        url TYPE string,
        lv_url TYPE char1024.

  parameter-name = 'BP'.
  parameter-value = bp.
  APPEND parameter TO parameters.
  IF nearby = 'X'.
    parameter-name = 'SHOW_NEAR'.
    parameter-value = nearby.
    APPEND parameter TO parameters.
    parameter-name = 'DISTANCE'.
    dist_int = distance.
    parameter-value = dist_int.
    APPEND parameter TO parameters.
  ENDIF.

  CALL METHOD cl_bsp_runtime=>if_bsp_runtime~construct_bsp_url
    EXPORTING
      in_application = 'ZGEOCODE_OSM'
      in_page        = 'default.htm'
      in_parameters  = parameters
    IMPORTING
      out_abs_url    = url.
  lv_url = url.
  IF  gr_container IS NOT BOUND.
    CREATE OBJECT gr_container
      EXPORTING
        container_name = 'HTML_VIEWER'.
    CREATE OBJECT gr_viewer
      EXPORTING
        parent = gr_container.
    gr_viewer->enable_sapsso( 'X' ).
  ENDIF.

  " Getting the current URL is an asynchronous call to the
  " SAP GUI frontend
  gr_viewer->get_current_url( IMPORTING url = gv_currurl ).
  " To get the value right now we have to flush the
  " queue of the client framework
  cl_gui_cfw=>flush( ).
  IF lv_url NE gv_currurl.
    gr_viewer->show_url( lv_url ).
  ENDIF.

  CALL SCREEN 0100.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN 'BACK'.
      LEAVE TO SCREEN 0.
    WHEN '%EX'.
      LEAVE PROGRAM.
    WHEN 'RW'.
      LEAVE PROGRAM.
    WHEN OTHERS.
  ENDCASE.
ENDMODULE.                 " USER_COMMAND_0100  INPUT

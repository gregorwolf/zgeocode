CLASS zcl_bsp_bp_osm DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_crm_bsp_model_access_il .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_bsp_bp_osm IMPLEMENTATION.


  METHOD if_crm_bsp_model_access_il~modify.
  ENDMETHOD.


  METHOD if_crm_bsp_model_access_il~read.
* Not usabe due to the missing structure zcomt_bsp_bp_osm
*    DATA :
*      bp                TYPE bu_partner,
*      guid              TYPE crmt_object_guid,
*      parameters        TYPE tihttpnvp,
*      parameter         LIKE LINE OF parameters,
*      screen_structures TYPE TABLE OF zcomt_bsp_bp_osm,
*      screen_structure  LIKE LINE OF screen_structures.
*
** create url
*    READ TABLE it_object_key INDEX 1 INTO bp.
*    parameter-name = 'BP'.
*    parameter-value = bp.
*    APPEND parameter TO parameters.
*
*    CALL METHOD cl_bsp_runtime=>if_bsp_runtime~construct_bsp_url
*      EXPORTING
*        in_application = 'ZGEOCODE_OSM'
*        in_page        = 'default.htm'
*        in_parameters  = parameters
*      IMPORTING
*        out_abs_url    = screen_structure-url.
*
*    INSERT screen_structure INTO TABLE screen_structures.
*
*    et_screen_structure = screen_structures.
  ENDMETHOD.
ENDCLASS.

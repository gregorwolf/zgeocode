CLASS zcl_geocode_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CLASS-METHODS convert_geodata_for_blackberry
      IMPORTING
        !i_geodata TYPE geocoding
      EXPORTING
        !lat       TYPE string
        !lon       TYPE string .
    CLASS-METHODS convert_geodata_for_javascript
      IMPORTING
        !i_geodata TYPE geocoding
      EXPORTING
        !lat       TYPE string
        !lon       TYPE string .
    CLASS-METHODS get_geodata_for_bp
      IMPORTING
        !i_bpartner      TYPE bu_partner
      RETURNING
        VALUE(r_geodata) TYPE geocoding .
    CLASS-METHODS find_surrounding_bps
      IMPORTING
        !i_geodata       TYPE geocoding
        !i_distance      TYPE geodist
      RETURNING
        VALUE(r_bp_dist) TYPE zgeocode_bp_dist_table .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_geocode_helper IMPLEMENTATION.


  METHOD convert_geodata_for_blackberry.
    DATA: latsign TYPE char1,
          lonsign TYPE char1.
    " For BlackBerry we need the sign in front of the number
    lat = i_geodata-latitude.
    lon = i_geodata-longitude.

    IF i_geodata-latitude < 0.
      latsign = '-'.
      lat  = i_geodata-latitude  * -1.
    ENDIF.
    IF i_geodata-longitude < 0.
      lonsign = '-'.
      lon = i_geodata-longitude * -1.
    ENDIF.
    " For BlackBerry we have to remove the decimal .
    " http://na.blackberry.com/eng/deliverables/3803/GPS%20and%20BlackBerry%20Maps%20Development%20Guide.pdf
    REPLACE ALL OCCURRENCES OF '.' IN lat WITH ''.
    REPLACE ALL OCCURRENCES OF '.' IN lon WITH ''.
    " Also it seems that the number can be only 7 characters long
    lat = lat(7).
    lon = lon(7).
    " But the sign can be added
    CONCATENATE latsign lat INTO lat.
    CONCATENATE lonsign lon INTO lon.
  ENDMETHOD.


  METHOD convert_geodata_for_javascript.
    DATA: latsign TYPE char1,
          lonsign TYPE char1.
    " For Java Script we need the sign in front of the number
    lat = i_geodata-latitude.
    lon = i_geodata-longitude.

    IF i_geodata-latitude < 0.
      latsign = '-'.
      lat  = i_geodata-latitude  * -1.
    ENDIF.
    IF i_geodata-longitude < 0.
      lonsign = '-'.
      lon = i_geodata-longitude * -1.
    ENDIF.
    CONCATENATE latsign lat INTO lat.
    CONCATENATE lonsign lon INTO lon.
  ENDMETHOD.


  METHOD find_surrounding_bps.

*circumference type f,
*circumference = 2 * r_earth * pi.
    TYPES: BEGIN OF t_obj_location,
             objkey    TYPE swo_typeid,
             longitude	TYPE geolon,
             latitude  TYPE geolat,
           END OF t_obj_location.

    CONSTANTS r_earth TYPE i VALUE 6378137. " radius Earth: 6378137 m
    CONSTANTS pi TYPE p LENGTH 8 DECIMALS 14
                     VALUE '3.14159265358979'.

    DATA: alpha TYPE f.

    alpha = 180 * i_distance / ( r_earth * pi ).

    DATA: lon_min TYPE geolon,
          lon_max TYPE geolon,
          lat_min TYPE geolat,
          lat_max TYPE geolon.

    DATA: obj_locations  TYPE TABLE OF t_obj_location,
          obj_location   LIKE LINE OF obj_locations,
          bp_ext_guid    TYPE bu_partner_guid_bapi,
          bp_guid        TYPE bu_partner_guid,
          dist_bp        TYPE f,
          bp_dist        LIKE LINE OF r_bp_dist,
          centraldataorg TYPE bapibus1006_central_organ.

    lon_min = i_geodata-longitude - alpha.
    lon_max = i_geodata-longitude + alpha.
    lat_min = i_geodata-latitude - alpha.
    lat_max = i_geodata-latitude + alpha.

    SELECT geoobjr~objkey geoloc~longitude geoloc~latitude
      FROM geoobjr
      JOIN geoloc ON geoobjr~guidloc = geoloc~guidloc
        INTO CORRESPONDING FIELDS OF TABLE obj_locations
        WHERE geoobjr~objtype = 'BUS1006'
          AND geoobjr~objsubtype = 'ADDRESS'
          AND geoloc~longitude >= lon_min
          AND geoloc~longitude <= lon_max
          AND geoloc~latitude  >= lat_min
          AND geoloc~latitude  <= lat_max.

    LOOP AT obj_locations INTO obj_location.

      cl_geocalc=>distance_by_lonlat( EXPORTING longitude1 = obj_location-longitude
                                                latitude1  = obj_location-latitude
                                                longitude2 = i_geodata-longitude
                                                latitude2  = i_geodata-latitude
                                      IMPORTING distance   = dist_bp ).
      IF dist_bp <= i_distance AND dist_bp <> 0.
        bp_ext_guid = obj_location-objkey(32).
        bp_guid = bp_ext_guid.
        CALL FUNCTION 'BUPA_NUMBERS_GET'
          EXPORTING
            iv_partner_guid = bp_guid
          IMPORTING
            ev_partner      = bp_dist-partner.
        CALL FUNCTION 'BAPI_BUPA_CENTRAL_GETDETAIL'
          EXPORTING
            businesspartner         = bp_dist-partner
*           VALID_DATE              = SY-DATLO
          IMPORTING
*           CENTRALDATA             = CENTRALDATA
*           CENTRALDATAPERSON       = CENTRALDATAPERSON
            centraldataorganization = centraldataorg
*           CENTRALDATAGROUP        = CENTRALDATAGROUP
*           CENTRALDATAVALIDITY     = CENTRALDATAVALIDITY
*       TABLES
*           TELEFONDATANONADDRESS   = TELEFONDATANONADDRESS
*           FAXDATANONADDRESS       = FAXDATANONADDRESS
*           TELETEXDATANONADDRESS   = TELETEXDATANONADDRESS
*           TELEXDATANONADDRESS     = TELEXDATANONADDRESS
*           E_MAILDATANONADDRESS    = E_MAILDATANONADDRESS
*           RMLADDRESSDATANONADDRESS           = RMLADDRESSDATANONADDRESS
*           X400ADDRESSDATANONADDRESS          = X400ADDRESSDATANONADDRESS
*           RFCADDRESSDATANONADDRESS           = RFCADDRESSDATANONADDRESS
*           PRTADDRESSDATANONADDRESS           = PRTADDRESSDATANONADDRESS
*           SSFADDRESSDATANONADDRESS           = SSFADDRESSDATANONADDRESS
*           URIADDRESSDATANONADDRESS           = URIADDRESSDATANONADDRESS
*           PAGADDRESSDATANONADDRESS           = PAGADDRESSDATANONADDRESS
*           COMMUNICATIONNOTESNONADDRESS       = COMMUNICATIONNOTESNONADDRESS
*           COMMUNICATIONUSAGENONADDRESS       = COMMUNICATIONUSAGENONADDRESS
*           RETURN                  = RETURN
          .
        bp_dist-name = centraldataorg-name1.
        bp_dist-distance = dist_bp.
        MOVE-CORRESPONDING obj_location TO bp_dist-geodata.
        APPEND bp_dist TO r_bp_dist.
      ENDIF.
    ENDLOOP.

    SORT r_bp_dist BY distance.

  ENDMETHOD.


  METHOD get_geodata_for_bp.
    CONSTANTS: objtype    TYPE swo_objtyp VALUE 'BUS1006',
               objsubtype TYPE swo_objtyp VALUE 'ADDRESS'.

    DATA: bp           TYPE bu_partner,
          bp_guid_bapi TYPE bu_partner_guid_bapi,
          bp_guid      TYPE bu_partner_guid,
          addrnum      TYPE ad_addrnum,
          addrguid     TYPE bu_address_guid,
          addrguid_str TYPE bu_partner_guid_bapi,
          addrnumguids TYPE bupa_addrnumguid_table,
          addrnumguid  LIKE LINE OF addrnumguids,
          geodata_tab  TYPE bus_geodata_t,
          geodata      LIKE LINE OF geodata_tab.

    DATA: geoobjr TYPE geoobjr,
          geoloc  TYPE geoloc.

    DATA: obj_id TYPE swo_typeid,
          logsys TYPE logsys.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = i_bpartner
      IMPORTING
        output = bp.

    CALL FUNCTION 'OWN_LOGICAL_SYSTEM_GET'
      IMPORTING
        own_logical_system = logsys.


    CALL FUNCTION 'BAPI_BUPA_GET_NUMBERS'
      EXPORTING
        businesspartner        = bp
      IMPORTING
        businesspartnerguidout = bp_guid_bapi.

    bp_guid = bp_guid_bapi.

    CALL FUNCTION 'BAPI_BUPA_ADDRESSES_GET'
      EXPORTING
        businesspartner       = bp
      IMPORTING
        standardaddressnumber = addrnum
        standardaddressguid   = addrguid.

    addrnumguid-bupa_addrnum = addrnum.
    addrnumguid-bupa_addrguid = addrguid.
    APPEND addrnumguid TO addrnumguids.
* Get geo information
    CALL FUNCTION 'BUA_GEOLOC_GET_GEODATA'
      EXPORTING
        it_addrnumguid = addrnumguids
        i_partner_guid = bp_guid
        i_subtype      = 'ADDRESS'
      IMPORTING
        et_geodata     = geodata_tab.

    READ TABLE geodata_tab INTO geodata WITH KEY bupa_addrnum = addrnum bupa_addrguid = addrguid.
    IF sy-subrc = 0.
      MOVE-CORRESPONDING geodata TO r_geodata.
    ELSE.
      READ TABLE geodata_tab INTO geodata WITH KEY bupa_addrnum = addrnum.
      IF sy-subrc = 0.
        MOVE-CORRESPONDING geodata TO r_geodata.
      ELSE.
        addrguid_str = addrguid.
        CONCATENATE  bp_guid_bapi addrguid_str INTO obj_id.

        SELECT SINGLE * FROM geoobjr INTO geoobjr
          WHERE objkey = obj_id
            AND objtype = objtype
            AND objsubtype = objsubtype
            AND logsys = logsys.
        " It seems that somtimes the BP-GUID is not Part of the obj_id
        IF sy-subrc <> 0.
          bp_guid_bapi = '00000000000000000000000000000000'.
          CONCATENATE  bp_guid_bapi addrguid_str INTO obj_id.
          SELECT SINGLE * FROM geoobjr INTO geoobjr
            WHERE objkey = obj_id
              AND objtype = objtype
              AND objsubtype = objsubtype
              AND logsys = logsys.
        ENDIF.

        SELECT SINGLE * FROM geoloc INTO geoloc
          WHERE guidloc = geoobjr-guidloc.

        MOVE-CORRESPONDING geoloc TO r_geodata.

      ENDIF.
    ENDIF.

  ENDMETHOD.
ENDCLASS.

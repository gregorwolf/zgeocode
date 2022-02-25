*&---------------------------------------------------------------------*
*& Report  ZGEOCODE_NOMINATIM_TEST_SURR
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT  zgeocode_nominatim_test_surr.

DATA: geodata TYPE geocoding,
      bp_dists TYPE zgeocode_bp_dist_table,
      bp_dist LIKE LINE OF bp_dists.

PARAMETERS: bp   TYPE bu_partner DEFAULT '101',
            dist TYPE geodist    DEFAULT '20000'.

geodata = zcl_geocode_helper=>get_geodata_for_bp( bp ).

bp_dists = zcl_geocode_helper=>find_surrounding_bps(
    i_geodata  = geodata
    i_distance = dist
).

LOOP AT bp_dists INTO bp_dist.
  WRITE: /
         bp_dist-partner,
         bp_dist-distance,
         bp_dist-geodata-longitude,
         bp_dist-geodata-latitude.
ENDLOOP.

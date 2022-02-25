*&---------------------------------------------------------------------*
*& Report  ZTEST_GIS_ROUTE_YOURS
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT  ztest_gis_route_yours.

DATA: lo_georoute TYPE REF TO zcl_gis_route_yours.
" DATA: lo_georoute TYPE REF TO cl_gis_route_igs.

DATA: from TYPE geoposition,
      via  TYPE geoposition,
      to   TYPE geoposition.

DATA: distance TYPE geodist.

" Test URL http://www.yournavigation.org/?flat=48.057947090798&flon=12.569867451065&tlat=47.952712196478&tlon=12.607888747491&v=motorcar&fast=1&layer=mapnik

from-latitude  = '48.057947090798'.
from-longitude = '12.569867451065'.

via-latitude   = '47.999750674721'.
via-longitude  = '12.636863423522'.

to-latitude    = '47.952712196478'.
to-longitude   = '12.607888747491'.

CREATE OBJECT lo_georoute.

lo_georoute->if_gis_route~add_stop(
    id       = 'From'
    position = from ).

lo_georoute->if_gis_route~add_stop(
    id       = 'Via'
    position = via ).

lo_georoute->if_gis_route~add_stop(
    id       = 'To'
    position = to ).

lo_georoute->if_gis_route~execute( ).

lo_georoute->if_gis_route~get_route_info(
  IMPORTING
    distance = distance ).

WRITE: distance.

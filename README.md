# ZGEOCODE

This package contains the class ZCL_GEOCODE_NOMINATIM which implements the interface IF_GEOCODING_TOOL. Classes of that interface can be set in the customizing for geocoding addresses. To customize go to SAP NetWeaver -> General Settings -> Set Geocoding.

The geocoder class uses Nominatim (http://wiki.openstreetmap.org/wiki/Nominatim) geocoding service based on OpenStreetMap Data. Please read the wiki page for further information.

IMPORTANT: Nominatim is a free service and should be used with care. If you plan to do high volume geocoding consider implementing your own OpenStreetMap Server.

## How does it work?

When the class is activated in the customizing every address maintained i.e. via transaction BP is passed to the geocoding class. From the address data we build an URL that calls the Nominatim web service and a XML document is returned. This document is parsed and put in the format of SAP's geocoding interface. SAP saves the geocoded information in the table GEOLOC. The link to the business partner address is saved in the GEOOBJR table.

## Setup

Make shure that your ABAP application server can connect to https://nominatim.openstreetmap.org/. You can create a HTTP destination in SM59 to test this. When you're behind a corporate firewall you have to configure a HTTP proxy. The global HTTP proxy setting can be done in transaction SICF.

In the Customizing at SAP NetWeaver -> General Settings -> Set Geocoding -> Register Geocoding Program in the System we add this line:

```
Source: ZNOM
Class:  ZCL_GEOCODE_NOMINATIM
Text:   Geocoding with OpenStreetMap Nominatim
```

Then in the next customizing step "Assign Geocoding Program to Countries" we add this line:

```
Country:   DE
Sequence:  4.000
Source:    ZNOM
Exclusive: X
```

If you want to maintain the geocoder for all countries run the report GEOCODING_CUSTOMIZING_MASS from the Package SZGEOCODING.

The last step is adding these lines in the customizing for "Assign Relevant Address Fields for Geocoding":

| Source | Field      |
| ------ | ---------- |
| ZNOM   | CITY1      |
| ZNOM   | CITY2      |
| ZNOM   | COUNTRY    |
| ZNOM   | HOUSE_NUM1 |
| ZNOM   | HOUSE_NUM2 |
| ZNOM   | POST_CODE1 |
| ZNOM   | REGION     |
| ZNOM   | STREET     |

You can check the customizing with the report GEOCODING_CUSTOMIZING_VERIFY.

## Test

You can run the standard report GEOCODING_FIRST to test your settings. For the standard address it should return something like:

8,643766362725 49,294217577528 ZNOM 600

## Usage in the SAP NetWeaver ABAP Developer Edition

### Create Business Partners

Start Transaction BP and create some Business Partners with an existing Address. It could happen that you need to customize the number ranges for the Business partners first. If you have already existing business partners that are not geocoded, then you can use the standard report BUPGEOENADDR to geocode them.

### ABAP Demo Program ZGEOCODE_NOMINATIM_READ_BP

With the program ZGEOCODE_NOMINATIM_READ_BP you can search for Business Partners and display their longitude and latitude. Also you can click on the Business Partner Number and start a Dynpro with an HTML Control displaying the address in OpenStreetMap using the BSP Application ZGEOCODE_OSM. You should have configuring the system to issue SAP Logon Tickets as described at http://help.sap.com/saphelp_nw70ehp1/helpdata/en/5c/b7d53ae8ab9248e10000000a114084/frameset.htm. Make sure that also the Fully Qualified Domain Names (FQDN) is set as described at http://help.sap.com/saphelp_nw70ehp1/helpdata/en/67/be9442572e1231e10000000a1550b0/frameset.htm.

## Links

- [Initial blog post: Community Project ZGEOCODE](https://blogs.sap.com/2010/04/10/community-project-zgeocode/)
- [SAP Community Wiki Page](https://wiki.scn.sap.com/wiki/display/ABAP/ZGEOCODE)
- [SAP TechEd 2010 Demo Jam Submission Video](https://youtu.be/t6FFTUHm7ns)

# Mahanama_SeismicRF_Fetch
Automated Script for Downloading and Processing Teleseismic Event Data for Receiver Function Analysis
This script automates the downloading, processing, and organization of teleseismic event data required for Receiver Function (RF) analysis. It fetches event catalogs, station metadata, seismic waveform data, and corresponding pole-zero (PZ) response files for instrument correction.

The main goal is to ensure efficient and structured data extraction, enabling researchers to select high-quality seismic waveforms for RF studies without manual filtering and organization.

Requirements:
Bash (Linux/macOS)
IRIS FDSN Services enabled

TauP Toolkit for travel-time calculations, for P-wave/P-Phases arrival calculations (http://www.seis.sc.edu/TauP)

mseed2sac for miniSEED to SAC conversion (https://ds.iris.edu/ds/nodes/dmc/software/downloads/mseed2sac/2-1/)

IRIS FetchData script for waveform downloading (FetchData_original.pl - Included in the repository)
Main Script: Download_Teleseismic_RF_Data

Extra Scripts: RF_Event_Station_map_radial.m (For plotting)

Description_Download_Teleseismic_RF_Data.txt will explain all that you should know about the script.

📌 Purpose:
This script automates the downloading and processing of teleseismic event data for Receiver Function (RF) analysis by:

Fetching event catalogs from IRIS FDSN, 
Downloading station metadata, 
Computing P-wave arrival times using TauP Toolkit, 
Fetching and converting miniSEED waveform data to SAC format, 
Downloading Pole-Zero (PZ) response files for instrument correction.


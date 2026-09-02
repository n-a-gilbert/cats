# Synergistic effects of cats and urbanization on wildlife

### [Neil A. Gilbert](https://gilbertecology.com) and the [Urban Wildlife Information Network](https://www.urbanwildlifeinfo.org/)

### Data/code DOI: 
__________________________________________________________________________________________________________________________________________

## Abstract
Free-roaming domestic cats (*Felis catus*) have detrimental impacts on wildlife, but synergies with other anthropogenic stressors are poorly known. Using camera-trap data from a global
wildlife monitoring collaboration (40 cities, 3,339 sites, >900,000 camera-days), we quantified the joint effects of cat activity and urbanization on 1) the detection of 55 terrestrial
mammal species and 2) species richness. We found synergistic negative effects of cats and urbanization on wildlife: modest cat activity (cats detected on 20% of sampling days) more than
doubled the number of species lost over urbanization gradients compared to scenarios without cat activity. By identifying synergies between urbanization and cats as stressors to wildlife, our
results suggest a need to consider landscape context when evaluating the roles of cats as predators, competitors, and disease reservoirs for communities of terrestrial mammals in cities.

 $~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~$ <img src="https://github.com/n-a-gilbert/cats/blob/main/figures/figure_01.png" width="600" />

## Repository Directory

### code
 * [full_script.R](./code/full_script.R) Script to format data, fit models, and visualize results; we follow the advice of [Kellner et al. 2024](https://esajournals.onlinelibrary.wiley.com/doi/full/10.1002/ecy.4475) to provide all code in one script. **NOTE:** Due to data sharing expectations of the Urban Wildlife Information Network, we cannot share the raw photo-detection data tables with geographic coordinates. Thus, we commented out the first section of the script that formats these data, and provide the formatted data object in this repository such that it can be loaded to re-run analyses and produce visualizations.  

### data
 * [baar_camera_locations_fuzzed.shp](./data/baar_camera_locations_fuzzed.shp) Shapefile (other file extensions also included but not listed here) with camera locations (with noise added to protect locations) for Bariloche, Argentina; these are used in the making of Figure 1E.
 * [city_locations.shp](./data/city_locations.shp) Shapefile (other file extensions also included by not listed here) with locations of cities included in the analysis. Used to make Figure 1D.
 * [elton_mammal.txt](./data/elton_mammal.txt) Text file with EltonTraits data. Full details, including metadata, can be found in [Wilman et al. 2014](https://esajournals.onlinelibrary.wiley.com/doi/10.1890/13-1917.1). The `BodyMass-Value` column is the only trait information used.
 * [formatted_data.RData](./data/formatted_data.RData) RData object containing one dataframe, `all`, which provides formatted species detection data. Each row represents a detection record for an individual camera during one sampling campaigan. The table has the following columns:

  | Column name | Type | Description |
  |-------------|------|-------------|
  | Species | character | Species label; this is a UWIN-specific common name. Scientific names are provided in [iucn_name_list_query.csv](./data/iucn_name_list_query.csv) |
  | Season | character | Sampling campaign; the first two characters represent season (SP = spring, SU = summer, FA = fall, WI = winter), and the last two characters represent year (e.g., 21 = 2021 |
  | Site | character | Site (camera location) identifier |
  | City | character | City identifier |
  | Crs | double | Coordinate reference system for site coordinates; note that the coordinates are redacted per data sharing policies |
  | Y | double | Count of how many days during the campaign that the species was detected at the camera location |
  | J | double | Number of days the camera was active during the sampling campaign |
  | start | date | Start date of the sampling campaign |
  | end | date | End date of the sampling campaign |
  | ghm | double | Value of the [Global Human Modification layer](https://developers.google.com/earth-engine/datasets/catalog/CSP_HM_GlobalHumanModification) extracted at camera coordinates. This was performed in Google Earth Engine. The value ranges from 0 (low human disturbance) to 1 (maximum human disturbance) |
  | ncat | double | Number of days during the sampling campaign that a domestic cat was detected at the camera |
  | pcat | double| Proportion of days during the sampling campaign that a domestic cat was detected at the camera |       

 * [gHM_buffer5km.tif](./data/gHM_buffer5km.tif) Raster of the [Global Human Modification layer](https://developers.google.com/earth-engine/datasets/catalog/CSP_HM_GlobalHumanModification) for the Bariloche, Argentina, study area; used to create Fig. 1E. The data layer was cropped and exported from Google Earth Engine.
 * [iucn_name_list_query.csv](iucn_name_list_query.csv) Crosswalk table for UWIN species labels and scientific names according to IUCN. Note that this table has more rows than taxa included in the analysis because some of the broader taxonomic entities included in analysis (e.g., `weasel_sp`) correspond to multiple scientific names. Also note that taxonomic inconsistencies required that some scientific names be updated in [full_script.R](./code/full_script.R) for joining with [elton_mammal.txt](./data/elton_mammal.txt).

| Column name | Type | Description |
|-------------|-----|--------------|
| sp | character | Species label; this is a UWIN-specific common name, and corresponds to the `Species` column in the `all` dataframe included in [formatted_data.RData](./data/formatted_data.RData) |
| sci_name | character | Scientific name according to IUCN |


 * 
### results

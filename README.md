Better Beddit API
=================

Converts https://cloudapi.beddit.com (https://github.com/beddit/beddit-api) from auth token based to query parameter auth based to be used for example with Zapier or Google Spreadsheets.

Adds additional fields:
  - `properties.snoring_episodes_count` (instead of getting a count from Time-Value snoring episodes)
  - `deepness_levels` Sum of different deepness (0.00 to 1.00) levels in 0.10 increments

Also converts *all* Unix timestamps to ISO8601 UTC times.


Example usages
--------------

    http://better-beddit-api.herokuapp.com/v2/authenticated_user/sleeps?username=user@email.com&password=strongpassword
  
  Returns JSON with added fields

    http://better-beddit-api.herokuapp.com/v2/authenticated_user/sleeps.csv?username=user@email.com&password=strongpassword

  Returns CSV with added fields. Suitable for importing with `=IMPORTDATA(url)` function in Google Spreadsheet
  


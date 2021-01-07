# IP info

Displays info about IP address such as country and city

### Supported Games

* Day of Defeat: Source

### Installation

* Download latest [release](https://github.com/Dron-elektron/ip-info/releases) (compiled for SourceMod 1.10)
* Extract "plugins" and "translations" folders to "addons/sourcemod" folder of your server
* Download [curl certificate](https://curl.haxx.se/ca/cacert.pem) and put it into working directory

### Console Variables

* sm_ipinfo_working_directory - Working directory of the plugin [default: "ipinfo"]
* sm_ipinfo_certificate_name - Name of the SSL certificate [default: "cacert.pem"]
* sm_ipinfo_cache_directory - Cache directory for country and city [default: "cache"]

### Used API

* https://ipapi.co/

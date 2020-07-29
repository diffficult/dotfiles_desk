#!/usr/bin/env bash

#variable
#weatherreport="${XDG_DATA_HOME:-$HOME/.local/share}/weatherreport"

# Portable directory
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Size used for the icons is 24x24 (16x16 is also ok for a smaller panel)
readonly ICON="${DIR}/icons/gpu.png"

# GPU values
readonly WEATHER_REPORT="$(curl --silent http://wttr.in/$1?T0F)"
#readonly CURRENT_TEMP="$(curl --silent http://wttr.in/$1 | head $s | cut -c45-46)"
readonly CURRENT_TEMP="$(curl -s http://rss.accuweather.com/rss/liveweather_rss.asp\?metric\=1\&locCode\="SAM|AR|AR013|MENDOZA" | perl -ne 'use utf8; if (/Currently/) {chomp;/\<title\>Currently: (.*)?\<\/title\>/; my @values=split(":",$1); if( $values[0] eq "Sunny" || $values[0] eq "Mostly Sunny" || $values[0] eq "Partly Sunny" || $values[0] eq "Intermittent Clouds" || $values[0] eq "Hazy Sunshine" || $values[0] eq "Hazy Sunshine" || $values[0] eq "Hot") 
{
my $sun = "☀️";
binmode(STDOUT, ":utf8");
print "$sun";
}
if( $values[0] eq "Mostly Cloudy" || $values[0] eq "Cloudy" || $values[0] eq "Dreary (Overcast)" || $values[0] eq "Fog")
{
my $cloud = "⛅";
binmode(STDOUT, ":utf8");
print "$cloud";
}
if( $values[0] eq "Showers" || $values[0] eq "Mostly Cloudy w/ Showers" || $values[0] eq "Partly Sunny w/ Showers" || $values[0] eq "T-Storms"|| $values[0] eq "Mostly Cloudy w/ T-Storms"|| $values[0] eq "Partly Sunny w/ T-Storms"|| $values[0] eq "Rain")
{
my $rain = "🌧️";
binmode(STDOUT, ":utf8");
print "$rain";
}
if( $values[0] eq "Windy")
{
my $wind = "🌪";
binmode(STDOUT, ":utf8");
print "$wind";
} 
if($values[0] eq "Flurries" || $values[0] eq "Mostly Cloudy w/ Flurries" || $values[0] eq "Partly Sunny w/ Flurries"|| $values[0] eq "Snow"|| $values[0] eq "Mostly Cloudy w/ Snow"|| $values[0] eq "Ice"|| $values[0] eq "Sleet"|| $values[0] eq "Freezing Rain"|| $values[0] eq "Rain and Snow"|| $values[0] eq "Cold")
{
my $snow = "❄️";
binmode(STDOUT, ":utf8");
print "$rain";
}
if($values[0] eq "Clear" || $values[0] eq "Mostly Clear" || $values[0] eq "Partly Cloudy"|| $values[0] eq "Intermittent Clouds"|| $values[0] eq "Hazy Moonlight"|| $values[0] eq "Mostly Cloudy"|| $values[0] eq "Partly Cloudy w/ Showers"|| $values[0] eq "Mostly Cloudy w/ Showers"|| $values[0] eq "Partly Cloudy w/ T-Storms"|| $values[0] eq "Mostly Cloudy w/ Flurries" || $values[0] eq "Mostly Cloudy w/ Snow")
{
my $night = "🌛";
binmode(STDOUT, ":utf8");
print "$night";
}
print"$values[1]"; }')"

#### Panel
###if [[ $(file -b "${ICON}") =~ PNG|SVG ]]; then
###  INFO="<img>${ICON}</img>"
###  INFO+="<txt>"
###else
###  INFO="<txt>"
###fi
####INFO+="${GPU_UTIL}"
###INFO+=" $CURRENT_TEMP"°C"  "
###INFO+="</txt>"

# Tooltip
MORE_INFO="<tool>"
MORE_INFO+="${WEATHER_REPORT}"
MORE_INFO+="</tool>"

# Output panel
echo -e "<txt> ${CURRENT_TEMP} </txt>"

# Output hover menu
echo -e "${MORE_INFO}"




#!env bash
source http.sh

default_route() {
	local method="$1"
	local host="${2-}"
	local path="$3"
	local query="${4-}"
http_response "200 OK" "<h1>It works!</h1>
<ul>
	<li>Method: $method</li>
	<li>Host: $host</li>
	<li>Path: $path</li>
	<li>Query: $query</li>
</ul>
<hr>
<em>$HTTP_SERVER_BANNER</em>"
}

while true; do
	http_serve 0.0.0.0 8081
done
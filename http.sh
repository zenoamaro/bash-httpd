#!/usr/bin/env bash
set -e
set -u

HTTP_SERVER_BANNER=${HTTP_SERVER_BANNER-Bashttpd 0.1}

http_log() {
	local message="$@"
	local date=$(date)
	echo -e "[$date] $message" 1>&2
}

http_log_request() {
	http_log "${Request[Method]} ${Request[Path]} ${Request[Proto]}"
}

http_log_response() {
	http_log "${Response[Status]}"
}

http_server_date() {
	date '+%a, %d %b %Y %H:%M:%S %Z'
}

http_content_length() {
	local body="$1"
	echo $(wc -c <<< "$body")
}

http_accept_request() {
	local method url proto
	read -r method url proto
	if [[ ! $method =~ (OPTIONS|HEAD|GET|POST|PUT|PATCH|DELETE) ]]; then
		echo 'Bad method'
		return 1
	elif [[ -z $url ]]; then
		echo 'Bad route'
		return 2
	elif [[ ! $proto =~ (HTTP/1\.0|HTTP/1\.1) ]]; then
		echo 'Bad protocol'
		return 3
	fi
	Request[Method]="$method"
	Request[Path]="$url"
	Request[Proto]=$(echo "$proto" | tr -d '\r\n')
}

http_parse_headers() {
	local header value handled
	while read -r header value; do
		header=$(echo "$header" | tr -d '\r\n')
		[[ -z $header ]] && break
		[[ ! $header =~ :$ ]] && continue
		Request["${header/:/}"]=$(echo "$value" | tr -d '\r\n')
	done
}

http_accept() {
	http_accept_request
	http_parse_headers
}

http_dispatch() {
	local routes="$1"
	while read -r route handler; do
		[[ -z $route ]] && continue
		if [[ $route =~ ^${Request[Path]}/?$ ]]; then
			$handler
			return 0
		fi
	done <<<"$routes"
	http_404 # Default handler
}

http_respond() {
	local proto="${Response[Proto]-HTTP/1.1}"
	local status="${Response[Status]-200 OK}"
	local body="${Response[Body]-}"
	Response[Date]="$(http_server_date)"
	Response[Server]="$HTTP_SERVER_BANNER"
	Response[Content-Length]="$(http_content_length "$body")"
	Response[Connection]="close"
	#
	echo "$proto $status"
	for header in "${!Response[@]}"; do
		[[ $header =~ ^(Proto|Status|Body)$ ]] && continue
		echo "$header: ${Response[$header]}"
	done
	echo -e "\n$body"
}

http_404() {
	Response[Status]='404 NOT FOUND'
}

http_pipeline() {
	declare -A Request
	declare -A Response
	http_accept
	http_log_request
	http_dispatch "$routes"
	http_respond
	http_log_response
}

http_serve() {
	local address="$1"
	local port="$2"
	local routes="$3"
	local request_counter=0
	trap "rm -f .request*" EXIT
	while true; do
		local out_pipe=".request.$request_counter"
		request_counter=$(($request_counter + 1))
		#
		mkfifo "$out_pipe"
		cat "$out_pipe" | nc -l "$address" "$port" > >(
			http_pipeline > "$out_pipe"
		)
		rm -f "$out_pipe"
	done
}

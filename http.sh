#!env bash
set -e
set -u

HTTP_SERVER_BANNER=${HTTP_SERVER_BANNER-Bashttpd 0.1}

http_log() {
	local message="$@"
	local date=$(date)
	echo -e "[$date] $message" 1>&2
}

http_log_request() {
	local request="$(cat -)"
	local http_params=($(http_parse_request "$request"))
	local method="${http_params[0]}"
	local host="${http_params[1]}"
	local path="${http_params[2]}"
	local query="${http_params[3]-}"
	http_log "$host: $method $path $query"
	echo -e "$request"
}

http_log_response() {
	local response="$(cat -)"
	local header=( $(echo -e "$response" | head -n 1) )
	http_log "> ${header[@]:1}"
	echo -e "$response"
}

http_is_request() {
	local request="$1"
	local methods="GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS"
	egrep -q "^($methods) /[^ ]* HTTP/1\.1" <<< "$request"
}

http_parse_request() {
	local request="$1"
	local header="$(echo -e "$request" | grep '^GET ')"
	local method="$(echo "$header" | cut -d ' ' -f 1)"
	local route="$(echo "$header" | cut -d ' ' -f 2)"
	local path="$(echo "$route?" | cut -d '?' -f 1)"
	local query="$(echo "$route?" | cut -d '?' -f 2)"
	local host="$(echo -e "$request" | grep 'Host: ' | cut -d ' ' -f 2)"
	echo "$method" "$host" "$path" "$query"
}

http_server_date() {
	date '+%a, %d %b %Y %H:%M:%S %Z'
}

http_content_length() {
	local body="$1"
	echo $(wc -c <<< "$body")
}

http_response() {
	local status="$1"
	local body="$2"
	echo "HTTP/1.1 $status"
	echo "Date: $(http_server_date)"
	echo "Server: $HTTP_SERVER_BANNER"
	echo "Content-Length: $(http_content_length "$body")"
	echo "Connection: close"
	echo
	echo "$body"
}

http_bad_request() {
	local status='400 BAD REQUEST'
	local body='Bad request.'
	http_response "$status" "$body"
}

http_accept() {
	local method url proto headers
	read -r method url proto
	while read -r line; do
		line="$(echo $line | tr -d '[\r\n]')"
		[[ -z "$line" ]] && break;
		headers+="$line\n"
	done
	echo -e "$method $url $proto\n$headers"
}

http_dispatch() {
	local request="$(cat -)"
	if ! http_is_request "$request"; then
		http_bad_request
	else
		local http_params="$(http_parse_request "$request")"
		default_route $http_params
	fi
}

http_middleware() {
	http_accept \
	| http_log_request \
	| http_dispatch \
	| http_log_response
}

http_listen() {
	local address="$1"
	local port="$2"
	rm -f outcoming
	mkfifo outcoming
	trap "rm -f outcoming" EXIT
	cat outcoming | nc -w 1 -l "$address" "$port" > >(
		http_middleware > outcoming
	)
	rm -f outcoming
}

http_serve() {
	local address="$1"
	local port="$2"
	while true; do
		http_listen "$address" "$port"
	done
}
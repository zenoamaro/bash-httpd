#!env bash
source http.sh

index_route() {
	Response[Status]="200 OK"
	Response[Body]="<h1>It works!</h1>
<a href='detail'>Click here for details.</a>
<hr>
<em>$HTTP_SERVER_BANNER</em>"
}

detail_route() {
	Response[Status]="200 OK"
	Response[Body]="<h1>Details:</h1>
<ul>
	<li>Method: ${Request[Method]}</li>
	<li>Host:   ${Request[Host]}</li>
	<li>Path:   ${Request[Path]}</li>
</ul>
<a href='/'>Back</a>
<hr>
<em>$HTTP_SERVER_BANNER</em>"
}

http_serve 0.0.0.0 8081 '
	/ index_route
	/detail detail_route
'

#!/bin/bash

SERVER="192.168.0.10:9091 --auth admin:admin"
DIR=~/bin/scripts/series/titles/
LOGFILE=~/bin/scripts/dxtotal/log
WEBADDRESS="www.divxtotal2.net"
SERIESURI="series"

VERSION="1.2.1"

echo "dxtotal $VERSION - Copyleft (GPL v3) Julio Serrano 2016"
echo "Revisar nuevas series en DivxTotal y descargar las indicadas"
echo "según la misma estructura de clat."
echo

cd "$DIR"

log() {
	local name="$1"
	echo "`date +"%d/%m/%Y %H:%M"` $name" >> $LOGFILE
}

trim() {
	local FOO="$1"
	FOO_NO_EXTERNAL_SPACE="$(echo -e "${FOO}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	echo "$FOO_NO_EXTERNAL_SPACE"
}

#Note: this function is no longer used in the divxtotal versión of the script
function download {
	local name="$1"
	local line="$2"
	local series="$3"

	#Extraemos la url de la etiqueta href
	local url=`echo "$line" | grep '<a href="/torrent/' | grep "$name" | grep -Po 'href=".*?"' | sed 's/\(href="\|"\)//g'`
	echo ">>>Url: $url"
	echo ">>>Recuperando el magnet"
	#Extraemos el magnet.
	local magnet=`curl "http://www.elitetorrent.net$url" | grep magnet | grep -Po '"magnet:.*?"' | sed 's/\("magnet:\|"\)//g'`
	#echo ">$magnet<"
	while [[ $magnet == "" ]]; do
		echo "La recuperación del magnet ha fallado."
		echo "Esperando 5 segundos antes de reintentar..."
		sleep 5
		magnet=`curl "http://www.elitetorrent.net$url" | grep magnet | grep -Po '"magnet:.*?"' | sed 's/\("magnet:\|"\)//g'`
	done		

	echo ">>>magnet:$magnet"
	echo ">>>Añadiendo a transmission"

	folder=`cat "$DIR$series"`
	#Como quitamos "magnet:" de la cadena, después tenemos que aádir magnet:
	transmission-remote $SERVER --add "magnet:$magnet" --download-dir "$folder"
	#setDownloaded "$name"
}

function isSeries {
	local name="$1"
	local line="$2"
	local res=false

	#Recorremos el directorio de las series mismo de clat
	for serie in *; do
		#Si el nombre del archivo coincide con el de una serie
		if [[ ${name,,} == ${serie,,}* ]]; then
			echo ">>>Este archivo es de la serie $serie"
			episode=`echo $name | grep -oE '[0-9]{1,2}x[0-9]{1,3}'`

			res=$(isDownloaded "$serie" "$episode")
			if $res; then
				echo "    Ya lo tenemos"
			else
				# local dotname=`echo "$name" | tr " " .`
				# res=$(isDownloaded "$dotname")
				# if $res; then
				# 	echo "    Ya lo tenemos"
				# else
					echo "    No lo tenemos"
					#Llamamos a la funcion que descargará el archivo
					check "$name" "$line" "$serie" "$episode"
				#fi
			fi
			break
    	fi
	done 	
}

function docurl {
	local urlfrom="$1"
	local filename="$2"

	curl "$urlfrom" > "$filename"
	FILESIZE=$(stat -c%s "$filename")
	while [[ $FILESIZE == 0 ]]; do
		echo "La descarga ha fallado."
		echo "Esperando 5 segundos antes de volver a intentarlo..."
		sleep 5
		curl "$urlfrom" > "$filename"
		FILESIZE=$(stat -c%s "$filename")
	done	
}

function isDownloaded {
	local serie="$1"
	local episode="$2"
	local res=""


	echo "Nombre: $serie, Episodio: $episode" >&2
	serie=`unaccent utf-8 "$serie"`

	#Le preguntamos a transmission si ya tiene el archivo
	res=`transmission-remote $SERVER --list | tr . " " | grep -i "$serie" | grep "$episode"`
	
	#echo "$res" >&2
	if [[ ${#res} > 0 ]]; then
		echo true
	else
		#Hacemos la misma comprobación, sustituyendo espacios con puntos
		# local name=`echo "$serie" | tr " " .`
		# res=`transmission-remote $SERVER --list | grep "$name" | grep "$episode"`
		# if [[ ${#res} > 0 ]]; then
		# 	echo true
		# else
			echo false
		# fi
	fi
}

# function isDownloaded {
# 	local filename="$1"
# 	local res=""
# 	declare -a parts

# 	let i=0
# 	for part in $filename; do
# 		parts[i]=$part
# 		let i++
# 	done

# 	size=${#parts[@]}
# 	let size--

# 	local name=""
# 	for ((i=0; i<$size; i++)); do
# 		name="$name${parts[i]} "
# 	done

# 	local episodio="${parts[$size]}"

# 	name=`unaccent utf-8 "$name"`
# 	name="$(echo -e "${name}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
# 	#name=${name%?}

# 	echo "Nombre: $name, Episodio: $episodio" >&2

	

# 	#Le preguntamos a transmission si ya tiene el archivo
# 	res=`transmission-remote $SERVER --list | grep "$name" | grep "$episodio"`
	
# 	#echo "$res" >&2
# 	if [[ ${#res} > 0 ]]; then
# 		echo true
# 	else
# 		#Hacemos la misma comprobación, sustituyendo espacios con puntos
# 		name=`echo "$name" | tr " " .`
# 		res=`transmission-remote $SERVER --list | grep "$name" | grep "$episodio"`
# 		if [[ ${#res} > 0 ]]; then
# 			echo true
# 		else
# 			echo false
# 		fi
# 	fi
# }

function check {
	local name="$1"
	local line="$2"
	local series="$3"
	local episode="$4"

	#echo "Depuración..."
	#echo "$line"
	#echo "$name"
	#echo "$series"
	#echo "Fin depuración"

	echo "Descargando página de $series"
	#Extraemos la url de la etiqueta href
	local url=`echo "$line" | grep -Po "href='.*?'" | sed "s/\(href='\|'\)//g"`
	echo ">>> URL: $url"

	docurl "$url" "/tmp/divxtotal3.txt"
	#curl "http://www.divxtotal.com$url" > /tmp/divxtotal3.txt
	#iconv --from-code=ISO-8859-1 --to-code=utf-8 /tmp/divxtotal3.txt > /tmp/divxtotal4.txt
	#local url2=`cat /tmp/divxtotal3.txt | grep "$name" | grep '<a href="/torrents_tor/*' | grep -Po 'href=".*?"' | sed 's/\(href="\|"\)//g'`
	#echo "Nombre: >$name<"
	#echo "$series$episode"
	local url2=`cat /tmp/divxtotal3.txt | grep -m 1 "$episode" | grep -Po 'href=".*?"' | sed 's/\(href="\|"\)//g'`

	if [[ $url2 == "" ]]; then
		echo ">>> No se ha podido obtener la URL del torrent"
		return
	fi

	echo ">>> URL del torrent: $url2"
	
	echo ">>> Descargando torrent"
	
	curl "$url2" > "/tmp/torrent.torrent"

	echo ">>> Añadiendo a transmission"

	folder=`cat "$DIR$series"`
	#Como quitamos "magnet:" de la cadena, después tenemos que aádir magnet:
	transmission-remote $SERVER --add "/tmp/torrent.torrent" --download-dir "$folder"

	#Registramos la descarga
	log "$name"
	rm /tmp/torrent.torrent
	rm /tmp/divxtotal3.txt
}

fetchmore=false
if [[ $1 = "" ]]; then
	urlfrom="http://$WEBADDRESS/$SERIESURI/"
	fetchmore=true
elif [[ $1 == "-u" ]]; then
	urlfrom="$2"
else
	urlfrom="http://$WEBADDRESS/buscar.php?busqueda=$1 $2 $3 $4 $5 $6 $7 $8 $9"
fi

echo "Descargando portada de DivxTotal..."
echo "$urlfrom"

docurl "$urlfrom" "/tmp/divxtotaltemp.txt"

#Shall we fetch more pages than just the first?
if $fetchmore; then
	docurl "http://$WEBADDRESS/$SERIESURI/page/2/" "/tmp/divxtotaltemp2.txt"
	docurl "http://$WEBADDRESS/$SERIESURI/page/3/" "/tmp/divxtotaltemp3.txt"
	cat /tmp/divxtotaltemp2.txt >> /tmp/divxtotaltemp.txt
	cat /tmp/divxtotaltemp3.txt >> /tmp/divxtotaltemp.txt
fi

#curl "$urlfrom" | grep -Po '<a onmouseover="javascript:cambia_series.*?</a>' > /tmp/divxtotal.txt
cat /tmp/divxtotaltemp.txt | grep -Po '<p class="seccontnom">.*?</p>' > /tmp/divxtotal.txt


#FILESIZE=$(stat -c%s "/tmp/divxtotal.txt")
#while [[ $FILESIZE == 0 ]]; do
#	echo "La descarga ha fallado."
#	echo "Esperando 5 segundos antes de volver a intentarlo..."
#	sleep 5
#	curl "$urlfrom" | grep -Po '<p class="seccontnom">.*?</p>' > /tmp/divxtotal.txt
#	FILESIZE=$(stat -c%s "/tmp/divxtotal.txt")
#done
echo  "Descargada\n"
cat /tmp/divxtotal.txt | grep -oP '<a.*?</a>' > /tmp/divxtotal2.txt
echo "Procesando..."
# Link filedescriptor 10 with stdin
exec 10<&0
# stdin replaced with a file supplied as a first argument
exec < /tmp/divxtotal2.txt

let count=0

while read line; do
	#Queremos la etiqueta title, pero sólo su contenido
	name=`echo "$line" | grep -Po '">.*?</a>' | sed 's/\(">\|<\/a>\)//g'`
	if [[ $name != "Series" ]]; then
		#name=${name%?}
		name="$(echo -e "${name}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    	echo ">$name<"
    	#echo "#$line#"
    	((count++))
    	#Procesamos la serie. La variable line se necesitará después
    	isSeries "$name" "$line"
    fi
done

echo Número de series procesadas: $count

# restore stdin from filedescriptor 10
# and close filedescriptor 10
exec 0<&10 10<&-
rm /tmp/divxtotal.txt
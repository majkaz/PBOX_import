#!/bin/bash
# 
# is this a test? <- start as "PBOX_conflate.sh test"
testing="$@"


# get newest POST_SCHRANKY_??????.csv file
	files=( POST_SCHRANKY_*.csv )
	new=${files[${#files[@]}-1]}
	tmp=${new#*_}
	tmp=${tmp#*_}
	yyyymm=${tmp%.*}

# split into separate files
awk -F";" 'NR==1{h=$0;next}!seen[$1]++{f="Depo_"$1".csv"; print h > f}{print >> f}' $new

# prepare the ugly hack for disused:amenity=post_box
# download all disabled post boxes in Czechia
curl https://overpass-api.de/api/interpreter?data=area%5B%22name%22%3D%22%C4%8Cesko%22%5D%3Bnode%5B%22disused%3Aamenity%22%3D%22post%5Fbox%22%5D%28area%29%3Bout%20meta%3B%0A | 		
# ugly hack, change disused:amenity to amenity, 
# add alternate tag because of the source (will be removed from the new one)
# remove first 4 rows
	sed 's/<tag k="disused:amenity/<tag k="old_disused:amenity" v="post_box"\/> <tag k="amenity/g;1,4d' > all.osm
	# get temp.osm
	touch temp.osm
	
# loop over files, get back depos create json
	for f in Depo_?????.csv
	do
		tmp=${f#*_}
		depo=${tmp%.*}
		# has source empty coordinates?
		empty=$(awk -F";" 'NR>1 && !$5 {print $1;exit;}' $f)


		# create conflate profile, from PBOX.profile as the master one
		
		if [ "$empty" == "$depo" ]
		then 
			# is this a test?, if yes, have we got allready empty coords depo
			if [ "$testing" == "test" ]
			then
				if [ "$gotempty" = 1 ] 
				then
					rm "Depo_"$depo".csv"
					continue
				else
					echo "empty"
					gotempty=1
				fi
			fi
			echo
			echo "Zpracovává se "$depo
			echo
			./p.py $f geojson "Depo_"$depo
			
			prfname="Depo_"$depo".profile.py"
			cp PBOX.profile $prfname
			echo "# file $new; depo nr. $depo" >> $prfname
			echo "source = 'CP:$yyyymm'" >> $prfname
			echo "záznamy bez souřadnic, nespárované schránky se nebudou rušit"
			# file has empty coordinates -> post boxes are missing, no retagging
			echo "# no retagging, coordinates missing in source" >> $prfname
			# get all post_boxes in area
			echo "query='[amenity=post_box]'" >> $prfname
			# reduced search area around post_boxes to avoid wrong matching
			echo "max_distance = 200" >> $prfname
		else 
			# is this a test?, if yes, have we got allready all coords depo
			if [ "$testing" == "test" ]
			then
				if [ "$gotnonempty" = 1 ] 
				then
					rm "Depo_"$depo".csv"
					continue
				else
					gotnonempty=1
					echo "non empty"
				fi
			fi
			echo
			echo "Zpracovává se "$depo
			echo
			./p.py $f geojson "Depo_"$depo
			prfname="Depo_"$depo".profile.py"
			cp PBOX.profile $prfname
			echo "# file $new; depo nr. $depo" >> $prfname
			echo "source = 'CP:$yyyymm'" >> $prfname
			echo "všechny záznamy mají souřadnice"
			echo "disablované schránky jsou přetagovány na 'amenity:disused=post_box'"
			echo "schránky se načítají jen s ref"
			echo "načítají se i disablované schránky"
			# all coordinates included, geojson has all post_boxes 
			# all post_boxes should be in area, get post boxes with ref
			echo "query='[amenity=post_box][ref~\"$depo.*\"]'" >> $prfname
			# increase search area around post_boxes to avoid wrong matching
			echo "max_distance = 1500" >> $prfname
			# not found might be only disabled for some time, do not delete, retag
			# retagging to disused:amenity, to be deleted a year later (from source:yyyymm)
			# append to depo profile
			echo "tag_unmatched = {" >> $prfname
			echo "    'fixme': 'Zkontrolovat na místě, v souboru České pošty chybí'," >> $prfname
			echo "    'amenity': None," >> $prfname
			echo "	'note': None," >> $prfname
			echo "	'collection_times': None," >> $prfname
			echo "	'disused:amenity': 'post_box'," >> $prfname
			echo "	'source:collection_times': None" >> $prfname
			echo "}" >> $prfname
		fi
		echo
		# change collection_times time format to hh:mm if needed
		sed -i 's/\(collection_times.* \)\([0-9]:[0-9][0-9]\)/\10\2/g' "Depo_"$depo".geojson"
		# run conflate
		conflate -i "Depo_"$depo".geojson" -c "Depo_"$depo".json" \
			-o "Depo_"$depo".osm" --osm "Depo_"$depo"_qr.osm" "Depo_"$depo".profile.py"
		echo
		echo "Znovu, včetně vypnutých schránek"
		
		
		# rm temp file
		rm temp.osm
		
		# remove the closing tag
		sed 's/<\/osm>//' "Depo_"$depo"_qr.osm" | 
		# combine both files
		cat - all.osm > temp.osm
		
		# run conflate again, this time against the patched osm file
		conflate -i "Depo_"$depo".geojson" -c "Depo_"$depo"_2.json" \
			-o "Depo_"$depo"_2.osm" --osm temp.osm "Depo_"$depo".profile.py"

		# patch the resulting file
		# remove old_disused nodes again, this time from the resulting file 
		# && remove new nodes, we are not inserting any - new nodes have negative ids
		# count changed postboxes
		results=$(awk ' BEGIN {RS="node>" }!/disused.*disused/ && !/id="-/ { a++ } END { print a }' Depo_"$depo".osm)
		schr=$((results-1))
		echo "vyfiltrováno ................" $schr "schránek"
		if [[ $schr = 0 ]]
		then
			# no nodes returned
			echo "Beze změn"
			# clean up
			rm "Depo_"$depo".csv"
			rm "Depo_"$depo".geojson"
			rm "Depo_"$depo".json"
			rm "Depo_"$depo".osm"
			rm "Depo_"$depo"_2.json"
			rm "Depo_"$depo"_2.osm"
			rm "Depo_"$depo"_qr.osm"
			rm "Depo_"$depo".profile.py"
		else
			# run it again
			awk '
			BEGIN {RS="node>"; ORS="node>\n"; z = 1 }
			!/disused.*disused/ && !/id="-/ ' "Depo_"$depo"_2.osm" | 
			tac | sed '1s/node>//' | tac | xmlstarlet fo > "Depo_"$depo".osm"
			# remove the unpatched file
			rm "Depo_"$depo"_2.osm"
			
			# patch the resulting json file using gron, no new check needed
			gron  "Depo_"$depo"_2.json" | 
			awk 'BEGIN {RS="Feature"; ORS="Feature"};!/disused.*disused/ && !/id = -/' | 
			tac | sed '1s/Feature//' | tac | gron -u > "Depo_"$depo".json"
			rm "Depo_"$depo"_2.json"
		fi
		echo
	done


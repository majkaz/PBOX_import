# START master profile
add_source=True
dataset_id = 'cp'
no_dataset_id=True
duplicate_distance=0.1
master_tags = ('collection_times', 'operator')
transform = {
    'amenity': 'post_box',
	'operator': 'Česká pošta, s.p.',
	'_note': '-'
}

# END master profile


# file POST_SCHRANKY_201810.csv; depo nr. 26107
source = 'CP:201810'
query='[amenity=post_box][ref~"26107.*"]'
max_distance = 1500
tag_unmatched = {
    'fixme': 'Zkontrolovat na místě, v souboru České pošty chybí',
    'amenity': None,
	'note': None,
	'collection_times': None,
	'disused:amenity': 'post_box',
	'source:collection_times': None
}

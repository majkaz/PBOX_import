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


# file POST_SCHRANKY_201810.csv; depo nr. 10003
source = 'CP:201810'
# no retagging, coordinates missing in source
query='[amenity=post_box]'
max_distance = 200

import os
import psycopg2

filesystem = '/home/administrator/images/S/'
problematic_inspection_ids = ["20246132"]

def main ():
    for parent_data, db_path in missing_child_walker():
        data_idx, pjnr, ereart, e1, e2, e3, autor = parent_data
        new_ereart = getChildEreart(ereart, os.path.basename(db_path))

def problematic_inspection_walker():
    for root, dirs, files in os.walk(filesystem, topdown=True): # generate parent before children
        seperated = root.split(os.sep)
        if (len(seperated) >= 8 and seperated[7].split()[0] in problematic_inspection_ids):
            convertedPath = os.path.join("S:",*seperated[5:])
            yield convertedPath, root #, dirs, files

conn = psycopg2.connect(
    host=os.getenv('POSTGRES_HOST'),
    port=os.getenv('POSTGRES_PORT'),
    user=os.getenv('POSTGRES_USER'),
    password=os.getenv('POSTGRES_PASSWORD'),
    database='insp_3'
)
def get_es(linkOrdner):
    c = conn.cursor()
    get_events_query = f'''
    SELECT "Index", "PjNr", "EREArt", "E1", "E2", "E3", "Autor" FROM "Events"
    WHERE 
        "LinkOrdner" = '{linkOrdner}'
        AND (
            "EREArt" IN (5100,5200,5201,5202,5203,5204)
            OR "EventID" = 1910
        )
    '''
    c.execute(get_events_query)
    res = c.fetchall()
    has_res = len(res) > 0
    return has_res , None if not has_res else res[0]


def missing_child_walker():
    last_data = None
    for db_path, fs_path in problematic_inspection_walker():
        found_data, data = get_es(db_path)
        if found_data:
            last_data = data
            # all good. the datapoint allready exists
        else:
            yield last_data, db_path
                

def getChildEreart(ereart, basename):
    if ereart == 5000:
        # parent is a location, child shall be a category
        ereart = 5100
    elif ereart == 5100:
        # parent is a category, child shall be a prüfpunkt
        ereart = 5200
    elif ereart == 5200:
        # parent is a prüfpunkt, child shall be a mangel
        if "leicht" in basename:
            ereart = 5201
        elif "mittel" in basename:
            ereart = 5202
        elif "schwer" in basename:
            ereart = 5203
        else:
            ereart = 5204
    return ereart


if __name__ == "__main__":
    main()

# man kann immer linkordner nehmen: denn 0 (zero) results for:s
"""
    select * from "Events" 
	where 
			"LinkOrdner" is null 
		and "Link" is not null 
		and ( 	"EREArt" in (5100,5200,5201,5202,5203,5204) 
			or 	"EventID" = 1910)	
    ;
"""
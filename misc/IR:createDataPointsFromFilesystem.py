import os
import psycopg2

filesystem = '/home/administrator/images/S/'
problematic_inspection_ids = ["20246132"]

def main ():
    for parent_data, db_path in missing_child_walker():
        data_idx, pjnr, ereart, e1, e2, e3, autor = parent_data
        new_ereart = getChildEreart(ereart, os.path.basename(db_path))
        e1,e2,e3 = changeEs(new_ereart, pjnr, e1=e1, e2=e2)
        create_new_data_point(db_path, pjnr, new_ereart, e1, e2, e3, autor)


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

def changeEs(ereart,pjnr,**kwargs):
    if ereart == 5100:
        return getNextE(ereart,pjnr, **kwargs), 0, 0
    elif ereart == 5200:
        return kwargs["e1"], getNextE(ereart,pjnr, **kwargs), 0
    elif ereart in [5201, 5202, 5203, 5204]:
        return kwargs["e1"], kwargs["e2"], getNextE(ereart,pjnr, **kwargs)

def getNextE(ereart,pjnr,**kwargs):
    level = {
        5100: "E1",
        5200: "E2",
        5201: "E3",
        5202: "E3",
        5203: "E3",
        5204: "E3"
    }[ereart]
    
    additional_where = ""
    if level == "E3":
        additional_where += f'AND "E2" = {kwargs["e2"]}'
    elif level in ["E2", "E1"]:
        additional_where += f'AND "E1" = {kwargs["e1"]}'

    c = conn.cursor()
    get_e_query = f'''
        SELECT "{level}" FROM "Events"
        WHERE 
            "EREArt" = {ereart}
            AND "PjNr" = {pjnr}
            {additional_where}
        ORDER BY "{level}" DESC
        LIMIT 1
    '''
    c.execute(get_e_query)
    res = c.fetchall()
    return res[0][0]+1 if len(res) > 0 else 1

def create_new_data_point(db_path, pjnr, ereart, e1, e2, e3, autor):
    c = conn.cursor()
    insert_query = f'''
        INSERT INTO "Events" ("PjNr", "EREArt", "E1", "E2", "E3", "Autor", "LinkOrdner")
        VALUES ({pjnr}, {ereart}, {e1}, {e2}, {e3}, '{autor}', '{db_path}')
    '''
    c.execute(insert_query)
    conn.commit()

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
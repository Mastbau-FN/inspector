import os
import psycopg2
from nicegui import ui


useUI = True
filesystem = '/home/administrator/images/S/'
problematic_inspection_ids = ["20246132"]

def main ():
    add_incidence_column_if_not_exists()
    if useUI:
        main_ui("please wait, loading...", [], lambda:1)
        gen = missing_child_walker()
        next_data(gen)
        ui.run()
    else:
        for parent_data, db_path, _ in missing_child_walker():
            handle_data(parent_data, db_path)
        conn.close()

def next_data(gen):
    parent_data, db_path, fs_path, files = gen.__next__()
    name = os.path.basename(db_path)
    filepaths = [os.path.join(fs_path, file) for file in files]
    def ondone(kurztext):
        handle_data(parent_data, db_path, kurztext)
        next_data(gen)
    main_ui.refresh(name, filepaths, ondone)

@ui.refreshable
def main_ui(name, filepaths, ondone):
    with ui.row().classes('w-full no-wrap'):
        for filepath in filepaths:
            ui.image(filepath)
    ui.label(name)
    kurztext = ui.input(label='Beschreibung').classes('w-full no-wrap')
    ui.button('Speichern und nächster', on_click=lambda: ondone(kurztext.value))

def handle_data(parent_data, db_path, kurztext = ""):
    data_idx, pjnr, ereart, e1, e2, e3, autor = parent_data
    new_ereart = get_child_ereart(ereart, os.path.basename(db_path))
    e1,e2,e3 = change_es(new_ereart, pjnr, e1=e1, e2=e2)
    create_new_data_point(db_path, pjnr, new_ereart, e1, e2, e3, autor, kurztext)

def problematic_inspection_walker():
    for root, dirs, files in os.walk(filesystem, topdown=True): # generate parent before children
        seperated = root.split(os.sep)
        if (len(seperated) >= 8 and seperated[7].split()[0] in problematic_inspection_ids):
            convertedPath = os.path.join("S:",*seperated[5:])
            yield convertedPath, root, files #, dirs


def missing_child_walker():
    last_data = None
    for db_path, fs_path, files in problematic_inspection_walker():
        found_data, data = get_es(db_path)
        if found_data:
            last_data = data
            # all good. the datapoint allready exists
        else:
            yield last_data, db_path, fs_path, files
                

def get_child_ereart(ereart, basename):
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

def change_es(ereart,pjnr,**kwargs):
    if ereart == 5100:
        return get_next_e(ereart,pjnr, **kwargs), 0, 0
    elif ereart == 5200:
        return kwargs["e1"], get_next_e(ereart,pjnr, **kwargs), 0
    elif ereart in [5201, 5202, 5203, 5204]:
        return kwargs["e1"], kwargs["e2"], get_next_e(ereart,pjnr, **kwargs)
    
from dotenv import load_dotenv; load_dotenv()
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


def get_next_e(ereart,pjnr,**kwargs):
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

def create_new_data_point(db_path, pjnr, ereart, e1, e2, e3, autor, kurztext):
    c = conn.cursor()
    insert_query = f'''
        INSERT INTO "Events" ("KurzText", "PjNr", "EREArt", "E1", "E2", "E3", "Autor", "LinkOrdner", "Link", "incident_generated")
        VALUES ('{kurztext}', {pjnr}, {ereart}, {e1}, {e2}, {e3}, '{autor}', '{db_path}', '{db_path}/no_default_picture_yet', TRUE)
    '''
    c.execute(insert_query)
    conn.commit()

def add_incidence_column_if_not_exists():
    column_name = 'incident_generated'
    c = conn.cursor()
    c.execute(f'''
        SELECT column_name FROM information_schema.columns WHERE table_name = 'Events' AND column_name = '{column_name}'
    ''')
    res = c.fetchall()
    if len(res) == 0:
        c.execute(f'''
            ALTER TABLE "Events" ADD COLUMN "{column_name}" BOOLEAN DEFAULT FALSE
        ''')
        conn.commit()

if __name__ in {"__main__", "__mp_main__"}:
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
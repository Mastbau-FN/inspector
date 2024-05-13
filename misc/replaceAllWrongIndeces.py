import os
import psycopg2
import numpy as np
from dotenv import load_dotenv

load_dotenv()
rootdir = "../../images/S"
rootdirdb = "S:"
stolist = os.listdir(rootdir)

ins_list= ["20246132"]
wahrscheinlich_gut=["20246132","20236538","20236534","20236535","20236536","20236537","20236540","20246156"]
nothinghappendlist = ["20236554","20236550",]
newindexes = [("first",1)]



lastnameDict = {}
def selectindexfromevents(linkordner, echtername, nr,pjNr, **kwargs):
    # Establish a connection to the PostgreSQL database
    #print(os.getenv('POSTGRES_HOST'))
  
    
    try:
        conn = psycopg2.connect(
            host=os.getenv('POSTGRES_HOST'),
            port=os.getenv('POSTGRES_PORT'),
            user=os.getenv('POSTGRES_USER'),
            password=os.getenv('POSTGRES_PASSWORD'),
            database='insp_doubled'
        )
        #print("Connection to the database established successfully.")
    except psycopg2.Error as e:
        print("Error connecting to the database:", e)

    # Create a cursor object using the connection
    cursor = conn.cursor()
    linksplit = linkordner.split("S",1)
    linkordner = rootdirdb+linksplit[1]
    #print(linkordner)
    # SQL query to select all records from the 'events' table
    
        
    selectquery = f'SELECT "Index" FROM "Events" WHERE "LinkOrdner" LIKE \'{linkordner}_______{echtername}\';'
    #print(selectquery)
    
    # make this single quoted
    # Execute the query
    try:
        cursor.execute(selectquery)
        #print("Query executed successfully.")
        
        # Fetch all rows from the last executed statement
        fetchresult = cursor.fetchall()
        if (len(fetchresult)==0):
            print("no rows found")
            print(f'!!!!!!!!!!!!!!! linkordner: {linkordner}_______{echtername} does not exist in the database.')
            return
        oldIndeces = np.array(fetchresult)[:,0]
        #print("rows"+str(rows))
        cursor.close()
       
       # TODO Bei mehreren Mängeln innerhalb einerkategorie wird nur der erste ersetzt
        # if(len(oldIndeces)!=0):
        #     altenr = oldIndeces[0]
        #     if(len(oldIndeces)>1):
        #         print(str(oldIndeces))
        #     print("altnenr: "+str(altenr)+" ersetzt durch neue nr: "+ str(nr))
        #     replacequery = f'UPDATE "Events" SET "Index" = CASE WHEN "Index" = {altenr} THEN {int(nr)} ELSE "Index" END, "Link" = REPLACE("Link", \'{str(altenr)}\', \'{str(nr)}\'),"LinkOrdner" = REPLACE("LinkOrdner", \'{str(altenr)}\', \'{str(nr)}\') where "PjNr"={int(pjNr)}'
        #     cursor = conn.cursor()
        #     cursor.execute(replacequery)
        #     conn.commit()
        #     cursor.close()

        cursor = conn.cursor()
        # for i, oldIndex in enumerate(oldIndeces):

        global lastnameDict
        try:
            # wir haben es mit einem mangel zu tun
            mangel_idx = kwargs['mangel_idx']
            try:
                # diese art von mangel hatten wir schonmal, wollen also den nächste
                lastnameDict[echtername] += 1
            except KeyError:
                # wir haben diesen mangel noch nicht gesehen, wollen also den ersten seiner art
                lastnameDict[echtername] = 0
            _index = lastnameDict[echtername]
        except KeyError:
            # kein mangel, i.e. wir gehen zum nächsten prüfpunkt mit unabhängigen mängeln, resette also welche mängel wir bereits sahen
            lastnameDict = {}#defaultLastNameDict
            _index = 0
        oldIndex = oldIndeces[_index]

        if True:
            
            # replaceQuery = f'   UPDATE "Events" 
            #                     SET "Index" = {int(nr)} 
            #                     WHERE (
            #                         "LinkOrdner" LIKE \'{linkordner}_______{echtername}\' 
            #                         ORDER BY "Index" ASC
            #                         LIMIT 
            #                     )
            #                     AND "PjNr"={int(pjNr)}
            #                 '
            
            replaceQuery = f'''  
                    UPDATE "Events"                                                                 
                    SET                                                                             
                        "Index" = CASE WHEN "Index" = {oldIndex} THEN {int(nr)} ELSE "Index" END,   
                        "Link" = REPLACE("Link", \'{str(oldIndex)}\', \'{str(nr)}\'),               
                        "LinkOrdner" = REPLACE("LinkOrdner", \'{str(oldIndex)}\', \'{str(nr)}\')    
                    WHERE (                                                                         
                        "PjNr"={int(pjNr)}                                                    
                        -- AND "LinkOrdner" LIKE \'{linkordner}_______{echtername}\'                    
                        -- ORDER BY "Index" ASC                                                        
                        -- limit oldindex - 1 , 1 oder so als alternative zum auswählen des xten matches, aber sollte mit oldIndex = oldIndeces[mangel_idx] abgefrühstückt sein
                    )                                                                               
                '''

            cursor.execute(replaceQuery)
        conn.commit()
        cursor.close()

        #TODO: falls len == 0 dann set new 
        

            
            
    except psycopg2.Error as e:
            # Close the cursor and connection
        print("Error executing query:", e)
    conn.close()



def replaceallwrongindexes(path,name,pjNr, **kwargs):
    # if kat starts with -
    if name[0] == '-':
        splittedname = name.split('_')
        nr = splittedname[0]
        echtername = splittedname[1]
        if "mangel_idx" in kwargs:
            echtername = echtername.replace(" ","")
        selectindexfromevents(path,echtername,nr,pjNr, **kwargs)


for sto in stolist:
    strlist= os.listdir(os.path.join(rootdir,sto))
    for stra in strlist:
        inslist= os.listdir(os.path.join(rootdir,sto,stra))
        for ins in inslist:

            # Find Inspektion
            if any(substring in ins for substring in ins_list):
                pjNr = ins.split(" ")[0]
                print(pjNr)

                # get all kategories
                katlist= os.listdir(os.path.join(rootdir,sto,stra,ins))

                # replace wrong indexes and 
                for kat in katlist:
                    print(kat)
                    if os.path.isdir(os.path.join(rootdir,sto,stra,ins,kat)):

                        # replace wrong indexes in kategories and get prüfpoints list
                        replaceallwrongindexes(os.path.join(rootdir,sto,stra,ins),kat,pjNr)
                        
                        pplist = os.listdir(os.path.join(rootdir,sto,stra,ins,kat))



                        for pp in pplist:
                            print(pp)
                            replaceallwrongindexes(os.path.join(rootdir,sto,stra,ins,kat),pp,pjNr)
                            if os.path.isdir(os.path.join(rootdir,sto,stra,ins,kat,pp)):
                                mangellist = os.listdir(os.path.join(rootdir,sto,stra,ins,kat,pp))
                                print("list: "+str(mangellist))
                                if(len(mangellist)>1):
                                    print(len(mangellist))
                                for mangel_idx, mangel in enumerate(mangellist):
                                    print(f'mangel {mangel_idx}: '+mangel)
                                    
                                    replaceallwrongindexes(os.path.join(rootdir,sto,stra,ins,kat,pp),mangel,pjNr,mangel_idx = mangel_idx)
                                lastnameDict = {}
                print(ins)
            


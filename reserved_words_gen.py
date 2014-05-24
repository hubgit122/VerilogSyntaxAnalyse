fileHandle = open ("reserved_words.txt")

i=0
lines = fileHandle.readlines()
for line in lines:
    if line.endswith("\n"):
        lines[i] = line[0:-1]
        i += 1
        
def trim_upper(line):
    tmp = line.upper()
    if tmp[0] == "`":
        tmp = tmp[1:]+"_"
    if tmp[0] == "$":
        tmp = tmp[1:]+"__"
    tmp = "RES_"+tmp
    return tmp
        
for line in lines:
    print "%"+"token <value> %s"%(trim_upper(line))

for line in lines:
    tmp = trim_upper(line)
    print "this->insert(ReservedWordMapPair(\"%s\",%s));"%(line,tmp)    
    i+=1
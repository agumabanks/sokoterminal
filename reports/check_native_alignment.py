import zipfile,struct,sys,json
z=zipfile.ZipFile(sys.argv[1]); checks=[]
for n in z.namelist():
 if not (n.startswith(('lib/arm64-v8a/','lib/x86_64/')) and n.endswith('.so')): continue
 b=z.read(n); order='<' if b[5]==1 else '>'; off=struct.unpack_from(order+'Q',b,32)[0]; size,count=struct.unpack_from(order+'HH',b,54)
 loads=[]; relro=[]
 for i in range(count):
  typ,flags,offset,va,pa,fs,ms,align=struct.unpack_from(order+'IIQQQQQQ',b,off+i*size)
  if typ==1: loads.append(align)
  if typ==0x6474e552: relro.append((va+ms)%16384)
 checks.append({'library':n,'load_aligned':all(a>=16384 for a in loads),'relro_end_remainders':relro})
print(json.dumps({'count':len(checks),'load_failures':[x for x in checks if not x['load_aligned']],'relro_end_nonzero':[x for x in checks if any(x['relro_end_remainders'])]},indent=2))

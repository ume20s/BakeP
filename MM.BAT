echo off
masm bakep;
link bakep;
exe2bin bakep.exe bakep.com
del bakep.obj
del bakep.exe

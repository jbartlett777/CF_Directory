# CF_Directory
A faster version of the CFDirectory tag

The CFDirectory tag can be slow when recursing directories. The CF_Directory Custom Tag is designed to be a drop in replacement where you just replace "CFDirectory" with "CF_Directory".

During benchmark tests, this Custom Tag returned the directory listing in 40-50% less time than the ```CFDirectory``` tag. I suspect that the native tag recurses into itself which
causes parent directories to still reside in memory while diving into sub-directories (but I haven't tested that theory yet). This version does not recurse into itself, instead looping
over a array of directories to fetch, appending to that array in the event the recurse flag is passed.

> [!CAUTION]
> This tag is still under development

Directory: Required. Directory to return<br>
Name: Required. Name of variable to hold the results<br>
Sort: Column names of the return with "ASC" or "DESC" after, comma delimited. Default=Name ASC<br>
CaseSenstiveSort: true/false. Default=false<br>
Filter: Pipe delimited string. Default="". Ex: *.cfm|*.cfc<br>
Type: [all|dir|file]. Default=all<br>
Recurse: true|false. Default=false<br>
FullDetails: Returns extra details on the files such as create/access dates, dates in Zulu, access rights, owner<br>
FollowLinkedFolders: true|false. Default=false. If recursing into directories, follow or not follow symlinks or junctions. Only available if FullDetails=true<br>

# Examples
All dump displays are using my <a href="https://github.com/jbartlett777/CF_DumpVar">cf_dumpvar Custom Tag</a><br>

### Simple directory listing
```<CF_DIRECTORY Action="List" Directory="C:\CFM\GeoZip" Name="DirList">```
<img width="570" height="204" alt="image" src="https://github.com/user-attachments/assets/d6099e13-53c1-484a-8f47-fe44f255bfd0" />
> [!Note]
> Junctions aren't identified using the default Java method. Same as the CFDirectory tag.

### Recurse Directory
```<CF_DIRECTORY action="List" Directory="C:\CFM\GeoZip" Name="DirList" Recurse="true">```
<img width="644" height="296" alt="image" src="https://github.com/user-attachments/assets/1950e6db-a4d2-4c68-821e-6dea2c4eee89" />

### Full Details
```<CF_DIRECTORY action="List" Directory="C:\CFM\GeoZip" Name="DirList" FullDetails="true">```
<img width="1713" height="200" alt="image" src="https://github.com/user-attachments/assets/1307e198-3a8e-4e1e-ba00-151222632946" /><br>
Returns the Created Date, Modified Date, and last Access date in the current time zone as well as zulu.<br>
This method does detect the Directory Junction as a Linked directory but Java did not return the linked target.

### Alt Method (Windows)
```<CF_DIRECTORY action="List" Directory="C:\CFM\GeoZip" Name="DirList" Alt="true">```
<img width="569" height="204" alt="image" src="https://github.com/user-attachments/assets/943de8e3-aa01-4ff5-92c5-43242e2e7b9a" /><br>
Alt Method under Windows does catch the Directory Junction.

### Alt Full Method (Windows)
```<CF_DIRECTORY action="List" Directory="C:\CFM\GeoZip" Name="DirList" Alt="true" FullDetails="true">```
<img width="1531" height="203" alt="image" src="https://github.com/user-attachments/assets/af380eef-c744-4f0c-891f-a036814c8b59" /><br>
Alt method under Windows identifies the linked target directory.<br>
Future versions will return additional date details<br>
If fetching a SMB directory is very slow, using the Alt method should be close to native speed.


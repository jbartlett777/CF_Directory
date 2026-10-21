# CF_Directory
A faster version of the CFDirectory tag

The CFDirectory tag can be slow when recursing directories. The CF_Directory Custom Tag is designed to be a drop in replacement where you just replace "CFDirectory" with "CF_Directory".

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

<cfscript>
// Only process at the start of a tag calling
if (StructKeyExists(variables,"ThisTag")) {
	if (ThisTag.ExecutionMode EQ "end") exit "exittag";
}

// Define parameters
cfparam(name="Attributes.Directory", Type="String");
cfparam(name="Attributes.Name", Type="String");
cfparam(name="Attributes.Sort", Type="String", Default="");
cfparam(Name="Attributes.CaseSenstiveSort", Type="String", Default="NO");
cfparam(Name="Attributes.Filter", Type="String", Default="")
cfparam(Name="Attributes.Type", Type="String", Default="all");
cfparam(Name="Attributes.Recurse", Type="Boolean", Default="false");
cfparam(Name="Attributes.FollowLinkedFolders", Type="Boolean", Default="true");
cfparam(Name="Attributes.FullDetails", Type="Boolean", Default="false");
cfparam(Name="Attributes.Alt", Type="Boolean", Default="false");

// Lucee doesn't use the "Defaut" value clause, so default if not passed
if (!StructKeyExists(Attributes,"Sort")) Attributes.Type="";
if (!StructKeyExists(Attributes,"CaseSenstiveSort")) Attributes.CaseSenstiveSort=false;;
if (!StructKeyExists(Attributes,"Filter")) Attributes.Filter="";
if (!StructKeyExists(Attributes,"Type")) Attributes.Type="All";
if (!StructKeyExists(Attributes,"Recurse")) Attributes.Recurse=false;
if (!StructKeyExists(Attributes,"FollowLinkedFolders")) Attributes.FollowLinkedFolders=true;
if (!StructKeyExists(Attributes,"FullDetails")) Attributes.Type=false;
if (!StructKeyExists(Attributes,"Alt")) Attributes.Alt=false;

PathChar=Server.System.properties["file.separator"];

// Define the return query
if (Attributes.FullDetails) {
	DirInfo=QueryNew(
			"Name,UName,Size,Type,DateLastModified,Attributes,Mode,Directory,Link,Exists,Hidden,Read,Write,Execute,LinkTarget,DateLastModifiedZulu,CreationTime,CreationTimeZulu,LastAccessTime,LastAccessTimeZulu,Owner",
			"varchar,varchar,bigint,varchar,timestamp,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,timestamp,timestamp,timestamp,timestamp,timestamp,varchar"
		);
	ReturnDir=Duplicate(DirInfo);
} else {
	DirInfo=QueryNew(
			"Name,UName,Size,Type,DateLastModified,Attributes,Mode,Directory,Link",
			"varchar,varchar,bigint,varchar,timestamp,varchar,varchar,varchar,varchar"
		);
	ReturnDir=Duplicate(DirInfo);
}
QueryDeleteColumn(ReturnDir,"UName"); // Remove column used for case insensitve sorting
SortedDir="";

if (Attributes.Alt) {
	// Use command line listing instead of Java calls
	BATFile=Replace(GetTempDirectory(),"\","/","All") & "Dir_" & CreateUUID() & ".bat";
	DOSRegEx="(\d{2}\/){2}\d{4}\s{2}\d{2}:\d{2} (A|P)M\s+(<DIR>)?(\s|\d)+\s[\w\d\s\W\D\S]+?(\n|\r)";
	
	DirectoriesToList=ArrayNew(1);
	DirectoriesToList[1]=Attributes.Directory;

	while (ArrayLen(DirectoriesToList) GT 0) {
		CurrDir=DirectoriesToList[1];
		ArrayDeleteAt(DirectoriesToList,1);

		if (PathChar EQ "\") {
			// Windows
			fileWrite(BATFile, "DIR /N /-C /4 " & Chr(34) & Replace(CurrDir,"/","\","All") & Chr(34));
			cfexecute(
				name="#BatFile#",
				timeout="10",
				variable="Dir"
				);
			FileDelete(BATFile);
			Files=REMatchNoCase(DOSRegEx,Dir);
			// Loop over the directory return and parse out the info
			for (i=1; i LTE ArrayLen(Files); i=i+1) {
				LineDate=ParseDateTime(ListGetAt(Files[i],1," ") & " " & ListGetAt(Files[i],2," ") & " " & ListGetAt(Files[i],3," "));
				if (Left(ListGetAt(Files[i],4," "),1) EQ "<") {
					LineType="Dir";
					LineSize=0;
				} else {
					LineType="File";
					LineSize=Val(ListGetAt(Files[i],4," "));
				}
				for (q=1; q LTE 4;q=q+1) Files[i]=ListDeleteAt(Files[i],1," "); // Delete stuff before file anme
				LineName=Trim(Files[i]);
				JuncLoc=Find("[",LineName);
				if (JuncLoc AND Right(LineName,1) EQ "]") { // Symlink or junction
					LineJunction=Mid(LineName,JuncLoc + 1,999);
					LineJunction=Left(LineJunction,Len(LineJunction) - 1);
					LineName=Trim(Left(LineName,JuncLoc - 1));
				} else {
					LineJunction="";
				}
				if (!ListFind(".,..",LineName)) {
					// Append the current directory if recursing
					if (LineType EQ "Dir" AND Attributes.Recurse) DirectoriesToList[ArrayLen(DirectoriesToList) + 1]=CurrDir & "/" & LineName;

					QueryAddRow(DirInfo);
					QuerySetCell(DirInfo,"Name",LineName);
					QuerySetCell(DirInfo,"UName",UCase(LineName));
					QuerySetCell(DirInfo,"Size",LineSize);
					QuerySetCell(DirInfo,"Type",LineType);
					QuerySetCell(DirInfo,"DateLastModified",LineDate);
					QuerySetCell(DirInfo,"Directory",CurrDir);
					if (LineJunction NEQ "") {
						QuerySetCell(DirInfo,"Link","YES");
						if (Attributes.FullDetails) QuerySetCell(DirInfo,"LinkTarget",LineJunction);
					} else {
						QuerySetCell(DirInfo,"Link","NO");
					}


				}

			}
		} {
			// Unix
		}
	}
} else {
	// Java calls
	Files=createObject("java","java.nio.file.Files");
	LinkOption=createObject("java","java.nio.file.LinkOption");

	DosFileAttributes=createObject("java", "java.nio.file.attribute.DosFileAttributes");

	// Java LinkOption[] containing NOFOLLOW_LINKS.
	// This ensures attributes describe the symbolic link itself.
	LinkOptions=LinkOption.values();

	// Available attribute views vary by filesystem and operating system.
	Views=[
		"basic",
		"dos",
		"posix",
		"unix",
		"owner",
		"acl",
		"user"
	];

	// Windows attribute flags
	flags = {
		"ReadOnly":               1,
		"Hidden":                 2,
		"System":                 4,
		"Directory":             16,
		"Archive":               32,
		"Device":                64,
		"Normal":               128,
		"Temporary":            256,
		"Sparse File":          512,
		"Reparse Point":       1024,
		"Compressed":          2048,
		"Offline":             4096,
		"Not Indexed":         8192,
		"Encrypted":          16384,
		"Integrity Stream":   32768,
		"Virtual":            65536,
		"No Scrub Data":     131072,
		"Recall On Open":    262144,
		"Pinned":            524288,
		"Unpinned":         1048576,
		"Recall on Access": 4194304
	};


	DirectoriesToList=ArrayNew(1);
	DirectoriesToList[1]=Attributes.Directory;

	while (ArrayLen(DirectoriesToList) GT 0) {

		DirectoryData=createObject("java","java.io.File").init(DirectoriesToList[1]);
		Entries=DirectoryData.listFiles();

		
		if (isNull(Entries)) {
			ArrayDeleteAt(DirectoriesToList,1);
			continue; // Can't access directory, move on to the next one if any
		}

		for (Entry in Entries) {

			Info=StructNew("ordered");
			Info["Name"]=Entry.getName(); // Name
			Info["UName"]=UCase(Info["Name"]); // UName
			Info["Size"]=Entry.length(); // Size
			Info["Type"]=(Entry.isDirectory()) ? "Dir" : "File"; // Type

			if (ListFindNoCase("Dir,File",Attributes.Type) AND Attributes.Type NEQ Info["Type"]) continue; // Skip this entry as it's not the correct type requested
			//Info["DateLastModified"]=Entry.lastModified(); // DateLastModified
			Info["DateLastModified"]=DateAdd("s",Int(Entry.lastModified() / 1000),CreateDate(1970,1,1)); // Convert Epoc to date
			Info["Attributes"]=""; // Attributes
			Info["Mode"]=""; // Mode
			Info["Directory"]=Entry.getParent(); // Directory
			path=Entry.toPath();
			Info["Link"]=Files.isSymbolicLink(path); // Link

			if (Attributes.FullDetails) {			
				Info["Exists"]=Entry.exists();
				Info["Hidden"]=Entry.isHidden();
				Info["Read"]=Entry.canRead();
				Info["Write"]=Entry.canWrite();
				Info["Execute"]=Entry.canExecute();

				if (Info["Link"]) { // Identify the link target
					try {
						Info["LinkTarget"]=Files.readSymbolicLink(path).toString();
					} catch (any e) {
						Info["LinkTarget"]="";
					}
				} else {
					Info["LinkTarget"]="";
				}

				// Retrieve every available attribute from each supported view.
				Info["DateLastModifiedZulu"]="";
				Info["CreationTime"]="";
				Info["CreationTimeZulu"]="";
				Info["LastAccessTime"]="";
				Info["LastAccessTimeZulu"]="";
				Info["Owner"]="";

				Attribs=StructNew();

				for (View in Views) {

					try {
						javaAttributes=Files.readAttributes(
							path,
							View & ":*",
							LinkOptions
						);

						iterator=javaAttributes.entrySet().iterator();

						while (iterator.hasNext()) {
							attribute=iterator.next();
							Attribs[ListFirst(Attribute,"=")]=ListDeleteAt(Attribute,1,"=");
						}
					}
					catch (any e) {
						// Unsupported attribute views are expected.
						// Skip them and continue with other views.
					}
					// Set create/last/modified dates
					if (StructKeyExists(Attribs,"CreationTime")) {
						Info["CreationTimeZulu"]=Attribs.CreationTime;
						Info["CreationTime"]=DateConvert('Utc2local', Info["CreationTimeZulu"]); // Convert from zulu to local system time
					}
					if (StructKeyExists(Attribs,"LastAccessTime")) {
						Info["LastAccessTimeZulu"]=Attribs.LastAccessTime;
						Info["LastAccessTime"]=DateConvert('Utc2local', Info["LastAccessTimeZulu"]);
					}
					if (StructKeyExists(Attribs,"LastModifiedTime")) {
						Info["DateLastModifiedZulu"]=Attribs.LastModifiedTime;
						if (!IsDate(Info["DateLastModified"])) Info["DateLastModified"]=DateConvert('Utc2local', Info["DateLastModifiedZulu"]);
					}
					// Set Owner of item
					if (StructKeyExists(Attribs,"owner")) Info["Owner"]=Attribs.owner;
					// Set the windows attributes if any
					if (StructKeyExists(Attribs,"attributes")) {

						result = {
							decimal = Attribs.attributes,
							hexadecimal = "0x" & UCase(
								createObject("java", "java.lang.Long")
									.ToHexString(
										javacast("long", Attribs.attributes)
									)
							),
							flags = []
						};

						ReturnFlags="";

						for (flag in flags) {
							if (bitAnd(Attribs.attributes, flags[flag]) EQ flags[flag]) {
								ArrayAppend(result.flags, flag);
								ReturnFlags=ListAppend(ReturnFlags,flag);
							}
						}
						Info["Attributes"]=ReturnFlags;
					}
				}

				// Check for linked items
				if (ListFind(Info["Attributes"],"Reparse Point")) Info["Link"]="YES";
				if (Info["Type"] EQ "Dir" AND Attributes.Recurse) {
					if (Info["Link"] EQ "YES" AND Attributes.FollowLinkedFolders) {
						DirectoriesToList[ArrayLen(DirectoriesToList)+1]=Entry.getAbsolutePath();
					} else if (Info["Link"] EQ "NO") {
						DirectoriesToList[ArrayLen(DirectoriesToList)+1]=Entry.getAbsolutePath();
					}
				}
			} else {
				if (Info["Type"] EQ "Dir" AND Attributes.Recurse) DirectoriesToList[ArrayLen(DirectoriesToList)+1]=Entry.getAbsolutePath();
			}
			QueryAddRow(DirInfo,Info);
		}

		ArrayDeleteAt(DirectoriesToList,1); // Remove the directory we just parsed
	}
}

// Apply filtering
if (Attributes.Filter NEQ "") {
	try {
		WHERE="";
		WHEREArray=ArrayNew(1)
		for (i=1; i LTE ListLen(Attributes.Filter,"|"); i++) {
			WHERE=WHERE & " AND Name LIKE ?";
			WHEREArray[ArrayLen(WHEREArray) + 1]=Replace(ListGetAt(Attributes.Filter,i,"|"),"*","%","All");
		}
		WHERE=MID(WHERE,6,999);
		DirInfo=QueryExecute(
			"SELECT *
			FROM DirInfo
			WHERE #WHERE#",
			WHEREArray,
			{dbtype="Query"}
		);
	} catch (any2 e) {
		throw (type="Custom", Message="Invalid filter");
	}
}

// Apply sorting to resulting query
SortArgs=Attributes.Sort;
if (YesNoFormat(Attributes.CaseSenstiveSort) EQ "NO") SortArgs=ReplaceNoCase(SortArgs,"Name","UName");

try {
	if (Attributes.sort NEQ "") {
		DirInfo=QueryExecute(
			"SELECT *
			FROM DirInfo
			ORDER BY Directory asc, #SortArgs#",
			[],
			{dbtype="Query"}
		);
	} else {
		DirInfo=QueryExecute(
			"SELECT *
			FROM DirInfo
			ORDER BY Directory asc",
			[],
			{dbtype="Query"}
		);
	}
} catch (any2 e) {
	throw (type="Custom", Message="Invalid sort reference");
}

QueryDeleteColumn(DirInfo,"UName"); // Remove column used for case insensitve sorting

// Strip out the SQL Metadata so CFDUMP looks the same as a CFDirectory
ReturnDir=QueryAppend(ReturnDir,DirInfo);

Caller[Attributes.Name]=ReturnDir;
</cfscript>

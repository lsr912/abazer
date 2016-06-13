#!/usr/bin/perl
#ungraded from version 3, features: make it more convinent to use
#use example 1: squence_getLine_analyse/analyse.perl Makefile mtx_lock_checker.bdl output
#use example 2: squence_getLine_analyse/analyse.perl Makefile
#define data structure
%rules = ();
%ruleIOptions = ();	#the value is the reference of @IOptions
%ruleDOptions = ();	#the value is the reference of @DOptions
@Makefiles = ();
$MakefileCount = 0;
@fp_stack = ();	#use to save the $SRCFILE, to process include directive
$top = 0;

#main
$Makefiles[$MakefileCount++] = $ARGV[0];
$BDFile = @ARGV[1];
$BOFile = @ARGV[2];
for( $Makefile_i = 0; $Makefile_i < $MakefileCount; $Makefile_i++ ){
	$curMakefile = $Makefiles[$Makefile_i];
	&analyse($curMakefile);
	print("MakefileCount:$MakefileCount\n");
	print("Makefile_i:$Makefile_i\n");
}
&genBDLMakefile;
close(BDLMakefile);
#end of main

sub analyse{
	local($filename) = @_;
	local(%variables) = ();
	local($CURDIR);
	local(@IOptions) = ();
	local(@DOptions) = ();
	local($COMPILE) = "";
	local($pos);
	local(@words, $word);
	
	open($SRCFILE, "$filename") || die("unable to open $filename for reading");
	print("Analyse $filename now...\n");
	$CURDIR = $filename;
	$CURDIR =~ s/\w+$//;
	#$CURDIR =~ s/\/$//;
	print("CURDIR:$CURDIR:\n");

	#process a complete line in Makefile
	$line = &getLine;
	while( $line ne "" ){
		$line =~ s/\n$//;
		$line =~ s/#.*$//;	#discard comment
		$line =~ s/\s+$//;
		if( $line =~ /^\t/ ){	#command line
			if( $line =~ /\$\(MAKE\)/ ){
				&processCallMAKE($line, \%variables, $CURDIR);
			}
		}else{
			$line =~ s/^\s+//;

			#process variable definition
			@parts = split(/=/, $line);
			$part1 = $parts[0];
			$part1 =~ s/^\s+//;
			$part1 =~ s/\s+$//;
			$part1 =~ s/:$//;
			@words = split(/\W+/, $part1);
			if( (@parts > 1) and (@words == 1) ){	#variable definition
				$pos = index($line, "=", 0);
				$value = substr($line, $pos+1);
				$value =~ s/^\s+//;
				$value =~ s/\s+$//;
				#$value = &expandMacro($value, \%variables);#macro may be used first, then initialize
				$variables{$part1} = $value;
				print("variable definition:$part1:$value:\n");
				$line = &getLine;
				next;
			}

			#process the rule we use
			#print("whether is rule:$line:\n");
			@parts = split(/:/, $line);
			$part1 = $parts[0];
			$part1 =~ s/^\s+//;
			$part1 =~ s/\s+$//;
			$part1 = &expandMacro($part1, \%variables);
			@words = split(/\s+/, $part1);	#can not use \W+, because '.' is not match by \W
			if( (@words == 1) ){	#rule: (@parts > 1) and 
				#print("rule:$line:\n");
				if( ($part1 =~ /\.a$/) or not($part1 =~ /\./) ){
					$pos = index($line, ":", 0);
					$value = substr($line, $pos+1);
					$value =~s/^://;	#for :: rule
					$value =~ s/^\s+//;
					$value =~ s/\s+$//;
					#use variable definition to substitute, then whether .o file exists
					$value = &expandMacro($value, \%variables);
					if( ($value =~ /\.o\s/) || ($value =~ /\.o$/) ){
						print("the rule we use:$part1:$value:\n");
						if($part1 =~ /\.a$/){
							$part1 = $CURDIR.$part1;
							$part1 = &discardDotDot($part1);
						}
						local($VPATH);
						$VPATH = $variables{"VPATH"};
						print("VPATH:$VPATH:\n");
						$value = &transformPrerequisites($value, $CURDIR, $VPATH);
						
						$rules{$part1} = $value;
						print("the rule we use after processed:$part1:$value:\n");

						$ruleIOptions{$part1} = \@IOptions;	#??hangup??
						$ruleDOptions{$part1} = \@DOptions;
					}
				}elsif($part1 eq ".c.o"){
					#$line = &getLine;
					#$line = &expandMacro($line, \%variables);
					$COMPILE = &getLine;
					$COMPILE =~ s/^\s+//;
					$COMPILE =~ s/\s+$//;
				}
			}			
		}
		
		$line = &getLine;
	}
	#analyse $COMPILE
	if($COMPILE ne ""){
		$COMPILE = &expandMacro($COMPILE, \%variables);
		@words = split(/\s+/, $COMPILE);
		local($IOptionsCount, $DOptionsCount);
		foreach $word(@words){
			if($word =~ /^-I/){
				print("original -I:$word\n");
				$word =~ s/^-I//;
				$word = &discardDotDot($CURDIR.$word);
				$word = "-I".$word;
				print("transformed -I:$word\n");
				$IOptionsCount = @IOptions;
				$IOptions[$IOptionsCount] = $word;
			}elsif($word =~ /^-D/){
				print("-D:$word\n");
				$DOptionsCount = @DOptions;
				$DOptions[$DOptionsCount] = $word;
			}
		}
	}
	
	close($SRCFILE);
}

sub processCallMAKE{
	#process run MAKE command in Makefile
	#analyse the following string: for subdir in $(SUBDIRS); do      target=`echo $@ | sed 's/-recursive//'`;        echo making $$target in $$subdir;      (cd $$subdir && $(MAKE) $$target) || exit 1;          done
	local($line) = shift(@_);
	local($vars_ref) = shift(@_);
	local($CURDIR) = @_;
	local(@subdirs) = ();
	local($subdir) = "";
	local($cd) = "";
	local($pos);

	$line =~ s/^\s+//;	#discard \t in the head of line
	print("Call MAKE line:$line:\n");
	@stmts = split(/;/, $line);
	for($stmt_i = 0; $stmt_i < @stmts; $stmt_i++){
		$stmt = $stmts[$stmt_i];
		$stmt =~ s/^\s+//;
		$stmt =~ s/\s+$//;
		#print("stmt:$stmt\n");
		#process: "for subdir in $(SUBDIRS)"
		if( ($stmt =~ /^for\s/) and ($stmt =~ /\bin/) ){
			print("for_stmt:$stmt\n");
			if( $stmt =~ /\$/ ){
				$stmt = &expandMacro($stmt, $vars_ref);	#don't forget $vars_ref
			}
			print("for_stmt after expanded:$stmt\n");
			@words = split(/\s+/, $stmt);
			($words[0] eq "for") || die("error: the first word is not for\n");
			if( $words[2] eq "in" ){
				$subdir = $words[1];
				print("subdirs:$subdir=");
				for($word_i = 3; $words[$word_i] ne ""; $word_i++){
					$count = @subdirs;
					$subdirs[$count++] = $words[$word_i];
					print("$words[$word_i]:");
				}
				print("\n");
			}
		}
		#process: "cd $$subdir"
		if ( $stmt =~ /\bcd/ ){
			print("cd_stmt: $stmt\n");
			@words = split(/[\s\(]+/, $stmt);
			for($word_i = 0; $word_i < @words; $word_i++){
				if( $words[$word_i] eq "cd" ){
					$cd = $words[$word_i+1];
					#$cd = &expandMacro($cd, $vars_ref);
					print("cd:$cd\n");
				}
			}
		}
		#process: "      (cd $$subdir && $(MAKE) $$target) || exit 1"
		if ( $stmt =~ /\$\(MAKE\)/ ){
			print("MAKE_stmt: $stmt\n");
			@exprs = split(/[&|]/, $stmt);
			for($expr_i = 0; $expr_i < @exprs; $expr_i++){
				if( $exprs[$expr_i] =~ /\$\(MAKE\)/ ){
					$expr = $exprs[$expr_i];
					$expr =~ s/^\s+//;
					$expr =~ s/\)\s+$//;
					$pos = index($expr, "\$(MAKE)", 0);
					$makePara = substr($expr, $pos+7);
					$makePara =~ s/^\s+//;
					print("makePara:$makePara:");
					$makePara = &expandMacro($makePara, $vars_ref);
					print("makePara after expanded:$makePara:");
					
					#if -f option exists, find out the MakefileName
					$MakefileName = "";
					@words = split(/\s+/, $makePara);
					for($word_i = 0; $word_i < @words; $word_i++){
						if( $words[$word_i] eq "-f" ){
							$MakefileName = $words[$word_i+1];
							print("-f:$MakefileName\n");
						}
					}
					#if -C option exists
					for($word_i = 0; $word_i < @words; $word_i++){
						if( $words[$word_i] eq "-C" ){
							$cd = $words[$word_i+1];
							print("-C:$cd\n");
						}
					}
					#process the called Makefile
					$cd = $CURDIR.$cd;
					if($cd =~ /\.\./){
						$cd = &discardDotDot($cd);
					}
					if( $cd ne "" ){
						#$cd =~ s/\$\$//;
						if( $cd eq ("\$\$".$subdir) ){	#for
							for($subdir_i = 0; $subdirs[$subdir_i] ne ""; $subdir_i++){
								&insertMakefile($subdirs[$subdir_i], $MakefileName);
							}
						}else{
							if( $cd =~ /\$/ ){
								$cd = &expandMacro($cd, $vars_ref);
							}
							&insertMakefile($cd, $MakefileName);
						}
					}else{
						&insertMakefile($cd, $MakefileName);
					}
				}
			}
		}
	}		
}

sub insertMakefile{
	local($path) = shift(@_);
	local($MakefileName) = @_;
	local($fullMakefileName) = "";
	local($Makefile_i);

	print("insertMakefile:$path:$MakefileName:\n");
	if( ($path ne "") and not($path =~ /\/$/) ){
		$path .= "/";
	}
	if($MakefileName eq ""){
		if(-e $path."GNUMakefile"){
			$fullMakefileName = $path."GNUMakefile";
		}elsif( -e $path."makefile"){
			$fullMakefileName = $path."makefile";
		}elsif( -e $path."Makefile"){
			$fullMakefileName = $path."Makefile";
		}else{
			die("cannot find Makefile in $path directory");
		}
	}else{
		$fullMakefileName = $path.$MakefileName;
	}
	for($Makefile_i = 0; $Makefile_i < $MakefileCount; $Makefile_i++){
		if($fullMakefileName eq $Makefiles[$Makefile_i]){
			last;
		}
	}
	if($Makefile_i == $MakefileCount){
		print("real insert :$fullMakefileName:\n");
		$Makefiles[$MakefileCount++] = $fullMakefileName;
		print("$MakefileCount\n");
	}
}

sub getLine{
	local($line, $index);
	local(@words);
	$line = <$SRCFILE>;
	#print("$line");
	
	#if read to the end of file
	while( ($line eq "") and ($top > 0) ){	#error:ne
		close($SRCFILE);
		$SRCFILE = $fp_stack[$top-1];
		$top--;
		$line = &getLine;
	}
	
	#if $line ends with '\', then continue to read next line
	while( $line =~ /\\\n$/ ){
		$line =~ s/\\\n$/ /;
		$line .= <$SRCFILE>;
	}

	#process include directive
	if( $line =~ /^ +include[ \t]/ ){
		$line =~ s/#.*//;	#discard comments in include statements
		@words = split(/\s+/, $line);
		for($index=@words; $index > 1; $index--){	# $words[0] is "include"
			$fp_stack[$top++] = $SRCFILE;
			open($SRCFILE, "$words[$index-1]") || die("unable to open $words[$index-1] for reading");
		}
		$line = &getLine;
	}
	
	$line;	#make sure the $line is the return value
}

sub expandMacro{
	local($str) = shift(@_);
	local($vars_ref) = @_;

	print("expandMacro:$str:");
	while( ($str =~ /\$\(\w+\)/) or ($str =~ /\$\w+\s/) or ($str =~ /\$\w+$/) ){
		$str =~ s/\$(\w+)\s/$vars_ref->{$1} /g;
		$str =~ s/\$(\w+)$/$vars_ref->{$1}/g;
		$str =~ s/\$\((\w+)\)/$vars_ref->{$1}/g;
		#$str =~ s/\$\W//g;	#discard $@
		#$str =~ s/\$$//g;	#discard $ in the end
		#print("$str:");
	}
	print("$str:\n");
	$str;	#make sure return $var
}

#analyse %rules, gen BDLMakefiles
sub genBDLMakefile{
	local(@rule_indexes, $rule_count, $rule_i);
	local($dest, $prerequisites, $cc_comand);
	local(@files, $file_count, $file_i, $filename);
	local($prerequisites2, @files2, $file_count2, $file_i2, $filename2);
	local($IOptionsRef);
	local($DOptionsRef);
	local($IOptionsString, $DOptionsString);
	local($cfilenamesString);
	
	print("\n\n\ngen BDLMakefile now...\n\n");
	open(BDLMakefile, ">BDLMakefile");
	print BDLMakefile ("CC = ~/redpig/bugcheck/build/gcc/cc1\n");
	print BDLMakefile ("CFLAGS = -quiet\n");
	print BDLMakefile ("CPPFLAGS = \n");
	print BDLMakefile ("BDFile = $BDFile\n");
	print BDLMakefile ("BOFile = $BOFile\n");
	print BDLMakefile ("\n");
	@rule_indexes = keys(%rules);
	$rule_count = @rule_indexes;
	for($rule_i = 0; $rule_i < $rule_count; $rule_i++){
		$dest = $rule_indexes[$rule_i];
		if( not($dest =~ /\.a$/) ){
			#rule whose dest is excutable program
			print BDLMakefile ("$dest: .PHONY");
			#$cc_command = "/usr/libexec/cc1 -bdf $BDFile -bof $BOFile ";
			$IOptionsString = "";
			$DOptionsString = "";
			$cfilenamesString = "";
			$IOptionsRef = $ruleIOptions{$dest};
			$IOptionsString .= &myJoin(" ", $IOptionsRef);
			$DOptionsRef = $ruleDOptions{$dest};
			$DOptionsString .= &myJoin(" ", $DOptionsRef);
			
			$prerequisites = $rules{$dest};
			print("$dest:$prerequisites\n");
			@files = split(/\s+/, $prerequisites);
			$file_count = @files;
			for($file_i = 0; $file_i < $file_count; $file_i++){
				$filename = $files[$file_i];
				if( $filename =~ /\.c$/ ){
					#$filename =~ s/\.o$/\.c/;
					#print BDLMakefile (" $filename");
					#$cc_command .= " $filename";
					$cfilenamesString .= " $filename";
				} elsif( $filename =~ /\.a$/ ){
					$IOptionsRef = $ruleIOptions{$filename};
					$IOptionsString .= " ".&myJoin(" ", $IOptionsRef);
					$DOptionsRef = $ruleDOptions{$filename};
					$DOptionsString .= " ".&myJoin(" ", $DOptionsRef);
					
					$prerequisites2 = $rules{$filename};
					#($prerequisites2 ne "") || die("cannot find the prerequisites of $filename!\n");
					@files2 = split(/\s+/, $prerequisites2);
					$file_count2 = @files2;
					for($file_i2 = 0; $file_i2 < $file_count2; $file_i2++){
						$filename2 = $files2[$file_i2];
						if( $filename2 =~ /\.c$/ ){
							#$filename2 =~ s/\.o$/\.c/;
							#print BDLMakefile (" $filename2");
							#$cc_command .= " $filename2";
							$cfilenamesString .= " $filename2";
						}
					}
				}
			}
			#$cc_command = "/usr/libexec/cc1 -quiet -bdf $BDFile -bof $BOFile ";
			#$cc_command = "/usr/libexec/cc1 -quiet ";
			#$cc_command = "~/bugcheck_build/gcc/cc1 -quiet -bdf $BDFile -bof $BOFile ";
			$cc_command = "\$(CC) \$(CFLAGS) \$(CPPFLAGS) -bdf \$(BDFile) -bof \$(BOFile) ";
			#$cc_command = "\$(CC) \$(CFLAGS) \$(CPPFLAGS) \$(BDFile) \$(BOFile) ";
			$cc_command .= $IOptionsString." ".$DOptionsString." ".$cfilenamesString;
			print BDLMakefile ("\n\t$cc_command\n\n");
			print("cc_command:$cc_command\n");
		}
	}
	close(BDLMakefile);
}

sub transformPrerequisites{
	local($prerequisites) = shift(@_);
	local($CURDIR) = shift(@_);
	local($VPATH) = @_;
	local(@paths, $path);
	local(@vpaths, $vpathCount, $vpath_i, $vpath);
	local(@filenames, $filename, $fullFilename);
	local($retv) = "";

	@vpaths = ();
	if($VPATH ne ""){
		@paths = split(/:/, $VPATH);
		foreach $path(@paths){
			$path =~ s/^\s+//;
			$path =~ s/\s+$//;
			if( not($path =~ /\/$/) ){
				$path .= "/";
			}
			$vpathCount = @vpaths;
			$vpaths[$vpathCount] = &discardDotDot($CURDIR.$path);
		}
	}
	
	$prerequisites =~ s/^\s+//;
	$prerequisites =~ s/\s+$//;
	@filenames = split(/\s+/, $prerequisites);
	foreach $filename(@filenames){
		if($filename =~ /\.o$/){
			$filename =~ s/\.o$/\.c/;
			$fullFilename = &discardDotDot($CURDIR.$filename);
			if(-e $fullFilename){
				$retv .= " ".$fullFilename;
			}else{
				local($exist) = "false";
				for($vpath_i = 0; $vpath_i < @vpaths; $vpath_i++){
					$vpath = $vpaths[$vpath_i];
					$fullFilename = &discardDotDot($vpath.$filename);
					if(-e $fullFilename){
						$retv .= " ".$fullFilename;
						$exist = "true";
						last;
					}
				}
				#($exist eq "true") || die("cannot find $filename, CURDIR:$CURDIR, VPATH:$VPATH!");
			}
		}elsif($filename =~ /\.a$/){
			$fullFilename = &discardDotDot($CURDIR.$filename);
			$retv .= " ".$fullFilename;
		}elsif($filename =~ /^-l/){	#load library
			$filename =~ s/^-l//;
			$filename = "lib".$filename.".a";
			$fullFilename = &discardDotDot($CURDIR.$filename);
			if(-e $fullFilename){
				$retv .= " ".$fullFilename;
			}else{
				local($exist) = "false";
				for($vpath_i = 0; $vpath_i < @vpaths; $vpath_i++){
					$vpath = $vpaths[$vpath_i];
					$fullFilename = &discardDotDot($vpath.$filename);
					if(-e $fullFilename){
						$retv .= " ".$fullFilename;
						$exist = "true";
						last;
					}
				}
				#($exist eq "true") || die("cannot find $filename, CURDIR:$CURDIR, VPATH:$VPATH!");
			}
		}
	}
	$retv =~ s/^ //;
	print("transform prerequisites:$prerequisites=>$retv,CURDIR:$CURDIR, VPATH:$VPATH\n");
	$retv;	#make sure return $retv
}

sub discardDotDot{
	local($path) = @_;

	print("discardDotDot:$path");
	$path =~ s/\/\w+\/\.\.\//\//g;
	$path =~ s/^\w+\/\.\.\///g;
	print("=>$path\n");
	$path;
}
					
sub myJoin{
	local($delimit) = shift(@_);
	local($arrayRef) = @_;
	local($str) = "";
	local($i);
	for($i = 0; $arrayRef->[$i] ne ""; $i++){
		if($i > 0){
			$str .= $delimit;
		}
		$str .= $arrayRef->[$i];
	}
	print("myJoin result:$str:\n");
	$str;   #make sure return $str
}
																		

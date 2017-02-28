import sys
import os
from datetime import date
###################################################################OPEN FOLDERS#######################################################
#Open Folder For SPF
if not os.path.exists('./SPF/'):
	os.makedirs('./SPF/')
#Open Folder For Vault
if not os.path.exists('./VAULT/'):
	os.makedirs('./VAULT/')
#Open Folder For ITRACE
if not os.path.exists('./ITRACE/'):
	os.makedirs('./ITRACE/')
#Open Folder For BLANKET
if not os.path.exists('./BLANKET/'):
	os.makedirs('./BLANKET/')
#Open Folder For CI_PLIST
if not os.path.exists('./CI_PLIST/'):
	os.makedirs('./CI_PLIST/')
#Open Folder For VCF
if not os.path.exists('./VCF/'):
	os.makedirs('./VCF/')
#Open Folder For VTPSIM
if not os.path.exists('./VTPSIM/'):
	os.makedirs('./VTPSIM/')
###################################################################EO OPEN FOLDERS######################################################
###################################################################Date#################################################################
YEAR = str(date.today().year)
MONTH = str(date.today().month)
DAY = str(date.today().day)
DATE='__'+DAY+'_'+MONTH +'_'+YEAR
###################################################################EO Date###############################################################
print 'IDV input Files Script Starting...'

Current_Folder=os.getcwd()

#get ituff file input from user
tpl_dir = raw_input("Drag here the Overall input file from excel: ");
tpl_file = open(tpl_dir, 'r')

#read all tpl file lines
tpl_file_lines = tpl_file.readlines()

#get ituff file input from user
tpl_dir1 = raw_input("Drag here the Fublet_contain file with template information: ");
tpl_file1 = open(tpl_dir1, 'r')

#read all tpl file lines
tpl_file_lines1 = tpl_file1.readlines()



##################################################EO PARSING Fublet_contain Input FILE output -> ARRAY ,index=Template Value= Array of OSCs######################################################						
Template_OSC_Array={}
counter=0;
# the '#' char represent not Mif template
for i in range(1, len(tpl_file_lines1)):
	if tpl_file_lines1[i].find('#') == -1:
		line_split=(tpl_file_lines1[i].rstrip()).split()
		temp=line_split[0].rstrip()
		OSC_Array = ((((line_split[1].rstrip()).split('|'))[1]).rstrip()).split(',')
		if counter==0:
			#enter the first template
			#split temp line temp=line_split[0] bank|osc1,osc2....oscn =line_split[1]
			Template_OSC_Array[temp]=OSC_Array
			counter=counter+1
		elif counter>0:
			try:
				if not Template_OSC_Array[temp] is None:
					#update the OSC array
					OSC1=set(OSC_Array)
					OSC2=set(Template_OSC_Array[temp])
					In_OSC1_Not_OSC2=OSC1-OSC2
					Updated_OSC_Array=Template_OSC_Array[temp]+list(In_OSC1_Not_OSC2)
					Template_OSC_Array[temp]=Updated_OSC_Array
			except:
				#first time of template
				Template_OSC_Array[temp]=OSC_Array
##################################################EO PARSING Fublet_contain Input FILE output -> ARRAY ,index=Template Value= Array of OSCs######################################################						
#Template_OSC_Array have all hte OSC in the Template
OSC_For_TAP={}
##############################PARSING TAP FUBLET Template Input FILE and cerating ICG input files per TAP-CTL###################################
#IDVSHIFT; -     IDVCTL;-   IDVSHIFTENREG; -      : IDVCTL   IOVCTL; -   : IOVBYPASS   IOVCTL1; IOVCTL2
for i in range(1, len(tpl_file_lines)):
	Flag_EOF=0
	if tpl_file_lines[i].split()[0] == 'TAP':
		
		
		
		#name = "Tap name"_"CTL name" 
		Folder_ICG_INPUT=Current_Folder+'/icg_input/'
		New_File_NAME=Current_Folder+'/icg_input/'+tpl_file_lines[i].split()[1]+ '-' + tpl_file_lines[i].split()[2]+'_'+DATE+'.icg'
		
		if not os.path.exists(Folder_ICG_INPUT):
			os.makedirs(Folder_ICG_INPUT)
			IDV_Input_file = open (New_File_NAME, 'w')
		else:
			IDV_Input_file = open (New_File_NAME, 'w')
		#ESPF tot name = TAP + CTL_name
		ESPF_Overall_NAME=tpl_file_lines[i].split()[1]+ '-' + tpl_file_lines[i].split()[2]
		
		j=i+1 #move to next line that have the Fublets
	counter=0
	while j<len(tpl_file_lines) and tpl_file_lines[j].split()[0] != 'TAP' :
		#print j
		try:
			line_splited=(tpl_file_lines[j].rstrip()).split()
		except:
			raw_input("end of input file,  press enter to exit")
			break
			
		if len(line_splited)>1:
			#There is Fub and template
			Fub_name=(tpl_file_lines[j].split()[0]).split('.')[0]
			Template=tpl_file_lines[j].split()[1]
			#OSCs for each ESPF FILE.
			if counter==0:
				try:
					OSC_For_TAP[ESPF_Overall_NAME]=Template_OSC_Array[Template]
					counter=counter+1
				except:
					counter=0
					#if its not Template that we have
			else:
				try:
					OSC1=set(Template_OSC_Array[Template])
					OSC2=set(OSC_For_TAP[ESPF_Overall_NAME])
					In_OSC1_Not_OSC2=OSC1-OSC2
					Updated_OSC_Array=OSC_For_TAP[ESPF_Overall_NAME]+list(In_OSC1_Not_OSC2)
					OSC_For_TAP[ESPF_Overall_NAME]=Updated_OSC_Array
				except:
					Liran=5
					#if its not Template that we have
			
			
		elif len(line_splited)==1:
			#Missing template
			Fub_name=(tpl_file_lines[j].split()[0]).split('.')[0]
			Template=''
			
		else:
			#Empty line
			Flag_EOF=1
			break
		
		
		to_print=Fub_name+' '+Template
		IDV_Input_file.write(to_print)
		IDV_Input_file.write('\n')
		
		j=j+1
	#Close the input file
	IDV_Input_file.close()
	
	if Flag_EOF==1:
		break
##############################EO PARSING TAP FUBLET Template Input FILE and cerating ICG input files per TAP-CTL###################################
#Open Files 1. Source from ESPF to SPF , 2. Vault file lines
ESPF_TO_SPF_Source_IDV_Input_file = open ('ESPF_TO_SPF_'+DATE+'.sh', 'w')
SPF_FOR_Vault_Input_file = open ('./VAULT/IDV_FOR_Vault_'+DATE+'.list', 'w')


###########################Creating ESPF files,SPF FOLDERS,source file with ESPF to SPF,Vault File with SPFs Full PAth#########################################

#Creating ESPF Files
for iterating_var in OSC_For_TAP:

	try:
		absolutely_unused_variable = os.system('clear')
	except: 
		absolutely_unused_variable = os.system("cls")
	
	
	
	InputCorrection=1
	while InputCorrection==1:
		try:
			#CODE#
			print 'ESPF Ceration'
			print 'Enter 1 if you want to Create ESPF for '+ iterating_var
			print 'Enter 2 if you Finished or Skip TAP'
			ESPF_var = input("")
			#EO CODE#
			InputCorrection=0
		except:
			print "ERROR: please Enter 1 OR 2"
			InputCorrection=1
	
	#Starting to create ESPF for specific TAP
	if str(ESPF_var)=="1":
		CTL_REG_NAME=iterating_var.split('-')[1]
		CHAIN_FOCUS=iterating_var.split('-')[0]
		FUBLET_Template_INPUT='./icg_input/'+iterating_var+'_'+DATE+'.icg'
		try:
			absolutely_unused_variable = os.system('clear')
		except: 
			absolutely_unused_variable = os.system("cls")
		CHAIN_VAR='LIRAN_M_T'
		
		#Registers
		print 'ESPF Register Fields for '+iterating_var + ' - Strings in quotes!!!!!'
		#1 Word in Control register
		if(len(CTL_REG_NAME.split('_'))==1):
			
			
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					print 'Enter 1 if you want to this config:'
					print '		Registers: IOVRESET,IOVCNTRA,IOVCNTRB,IOVCNTRALL,IOVCTL'
					
					print 'Enter 2 if you want to this config:'
					print '		Registers: IDVRESET,IDVCNTRA,IDVCNTRB,IDVCNTRALL,IDVCTL'
					
					print 'Enter 3 if you want to this config:'
					print '		Registers: IOVRESET1,IOVCNTRA1,IOVCNTRB1,IOVCNTRALL1,IOVCTL1'
					
					print 'Enter 4 if you want to this config:'
					print '		Registers: IOVRESET2,IOVCNTRA2,IOVCNTRB2,IOVCNTRALL2,IOVCTL2'
					
					print 'Enter 5 if you want diffrent config:'
					#print '	Registers: IDVRESET,IDVCNTRA,IDVCNTRB,IDVCNTRALL,IDVCTL'
					
					REG_ESPF_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter 1/2/3/4/5"
					InputCorrection=1
			
			
			
			
			if str(REG_ESPF_var)=="1":
				Reset_Register_var="IOVRESET"
				CounterA_Register_var="IOVCNTRA"
				CounterB_Register_var="IOVCNTRB"
				CounterALL_Register_var="IOVCNTRALL"
			elif str(REG_ESPF_var)=="2":
				Reset_Register_var="IDVRESET"
				CounterA_Register_var="IDVCNTRA"
				CounterB_Register_var="IDVCNTRB"
				CounterALL_Register_var="IDVCNTRALL"
			elif str(REG_ESPF_var)=="3":
				Reset_Register_var="IOVRESET1"
				CounterA_Register_var="IOVCNTRA1"
				CounterB_Register_var="IOVCNTRB1"
				CounterALL_Register_var="IOVCNTRALL1"
			elif str(REG_ESPF_var)=="4":
				Reset_Register_var="IOVRESET2"
				CounterA_Register_var="IOVCNTRA2"
				CounterB_Register_var="IOVCNTRB2"
				CounterALL_Register_var="IOVCNTRALL2"
			elif str(REG_ESPF_var)=="5":
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						#Reset Reg
						print 'Enter Reset Register Name'
						Reset_Register_var = input("")
						#CounterA Reg
						print 'Enter CounterA Register Name'
						CounterA_Register_var = str(input(""))
						#CounterB Reg
						print 'Enter CounterB Register Name'
						CounterB_Register_var = input("")
						#CounterALL Reg
						print 'Enter CounterALL Register Name'
						CounterALL_Register_var = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "ERROR: please Enter Registers Name in quotes"
						InputCorrection=1
				
			else:
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						#Reset Reg
						print 'Enter Reset Register Name'
						Reset_Register_var = input("")
						#CounterA Reg
						print 'Enter CounterA Register Name'
						CounterA_Register_var = str(input(""))
						#CounterB Reg
						print 'Enter CounterB Register Name'
						CounterB_Register_var = input("")
						#CounterALL Reg
						print 'Enter CounterALL Register Name'
						CounterALL_Register_var = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "please Enter Registers Name in quotes"
						InputCorrection=1
			
		#2 Words in Control register	
		elif(len(CTL_REG_NAME.split('_'))==2):
			
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					print 'Enter 1 if you want to this config:'
					print '		Registers: '+CTL_REG_NAME.split('_')[0]+'_IDVRESET,'+CTL_REG_NAME.split('_')[0]+'_IDVCNTRA,'+CTL_REG_NAME.split('_')[0]+'_IDVCNTRB,'+CTL_REG_NAME.split('_')[0]+'_IDVCNTRALL,'+CTL_REG_NAME
					
					print 'Enter 2 if you want to this config:'
					print '		Registers: IDVRESET_'+CTL_REG_NAME.split('_')[1]+',IDVCNTRA_'+CTL_REG_NAME.split('_')[1]+',IDVCNTRB_'+CTL_REG_NAME.split('_')[1]+',IDVCNTRALL_'+CTL_REG_NAME.split('_')[1]+','+CTL_REG_NAME
					
					print 'Enter 3 if you want to this config:'
					print '		Registers: '+CTL_REG_NAME.split('_')[0]+'_IDVVDMCONFIG,'+CTL_REG_NAME.split('_')[0]+'_IDVRESULTSA,'+CTL_REG_NAME.split('_')[0]+'_IDVRESULTSB,'+CTL_REG_NAME.split('_')[0]+'_IDVRESULTS,'+CTL_REG_NAME
					
					print 'Enter 4 if you want to this config:'
					print '		Registers: IDVRESET,IDVCNTRA,IDVCNTRB,IDVCNTRALL,'+CTL_REG_NAME
					
					print 'Enter 5 if you want diffrent config:'
				
					REG_ESPF_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter 1/2/3/4/5"
					InputCorrection=1
			
			
			if str(REG_ESPF_var)=="1":
				Reset_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVRESET'
				CounterA_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVCNTRA'
				CounterB_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVCNTRB'
				CounterALL_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVCNTRALL'
			elif str(REG_ESPF_var)=="2":
				Reset_Register_var='IDVRESET_'+CTL_REG_NAME.split('_')[1]
				CounterA_Register_var='IDVCNTRA_'+CTL_REG_NAME.split('_')[1]
				CounterB_Register_var='IDVCNTRB_'+CTL_REG_NAME.split('_')[1]
				CounterALL_Register_var='IDVCNTRALL_'+CTL_REG_NAME.split('_')[1]
			elif str(REG_ESPF_var)=="3":
				Reset_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVVDMCONFIG'
				CounterA_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVRESULTSA'
				CounterB_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVRESULTSB'
				CounterALL_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVRESULTS'
			elif str(REG_ESPF_var)=="4":
				Reset_Register_var='IDVRESET'
				CounterA_Register_var='IDVCNTRA'
				CounterB_Register_var='IDVCNTRB'
				CounterALL_Register_var='IDVCNTRALL'
			elif str(REG_ESPF_var)=="5":
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						#Reset Reg
						print 'Enter Reset Register Name'
						Reset_Register_var = input("")
						#CounterA Reg
						print 'Enter CounterA Register Name'
						CounterA_Register_var = str(input(""))
						#CounterB Reg
						print 'Enter CounterB Register Name'
						CounterB_Register_var = input("")
						#CounterALL Reg
						print 'Enter CounterALL Register Name'
						CounterALL_Register_var = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "ERROR: please Enter Registers Name in quotes"
						InputCorrection=1
				
			else:
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						#Reset Reg
						print 'Enter Reset Register Name'
						Reset_Register_var = input("")
						#CounterA Reg
						print 'Enter CounterA Register Name'
						CounterA_Register_var = str(input(""))
						#CounterB Reg
						print 'Enter CounterB Register Name'
						CounterB_Register_var = input("")
						#CounterALL Reg
						print 'Enter CounterALL Register Name'
						CounterALL_Register_var = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "ERROR: please Enter Registers Name in quotes"
						InputCorrection=1
		#3 Words in Control register for GT	
		elif(len(CTL_REG_NAME.split('_'))==3):
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					print 'Enter 1 if you want to this config:'
					print '		Registers: '+CTL_REG_NAME.split('_')[0]+'_IDVVDMCONFIG,'+CTL_REG_NAME.split('_')[0]+'_IDVRESULTSA,'+CTL_REG_NAME.split('_')[0]+'_IDVRESULTSB,'+CTL_REG_NAME.split('_')[0]+'_IDVRESULTS,'+CTL_REG_NAME
					
					print 'Enter 2 if you want diffrent config:'
				
					REG_ESPF_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter 1 OR 2"
					InputCorrection=1
			
			
			if str(REG_ESPF_var)=="1":
				Reset_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVVDMCONFIG'
				CounterA_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVRESULTSA'
				CounterB_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVRESULTSB'
				CounterALL_Register_var=CTL_REG_NAME.split('_')[0]+'_IDVRESULTS'
			elif str(REG_ESPF_var)=="2":
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						#Reset Reg
						print 'Enter Reset Register Name'
						Reset_Register_var = input("")
						#CounterA Reg
						print 'Enter CounterA Register Name'
						CounterA_Register_var = str(input(""))
						#CounterB Reg
						print 'Enter CounterB Register Name'
						CounterB_Register_var = input("")
						#CounterALL Reg
						print 'Enter CounterALL Register Name'
						CounterALL_Register_var = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "ERROR: please Enter Registers Name in quotes"
						InputCorrection=1
			else:
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						#Reset Reg
						print 'Enter Reset Register Name'
						Reset_Register_var = input("")
						#CounterA Reg
						print 'Enter CounterA Register Name'
						CounterA_Register_var = str(input(""))
						#CounterB Reg
						print 'Enter CounterB Register Name'
						CounterB_Register_var = input("")
						#CounterALL Reg
						print 'Enter CounterALL Register Name'
						CounterALL_Register_var = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "ERROR: please Enter Registers Name in quotes"
						InputCorrection=1
		#Strange CTL - ASK ALL
		else:
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					#Reset Reg
					print 'Enter Reset Register Name'
					Reset_Register_var = input("")
					#CounterA Reg
					print 'Enter CounterA Register Name'
					CounterA_Register_var = str(input(""))
					#CounterB Reg
					print 'Enter CounterB Register Name'
					CounterB_Register_var = input("")
					#CounterALL Reg
					print 'Enter CounterALL Register Name'
					CounterALL_Register_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter Registers Name in quotes"
					InputCorrection=1
			
		
		#Finish with reg
		try:
			absolutely_unused_variable = os.system('clear')
		except: 
			absolutely_unused_variable = os.system("cls")
		
		#Tap Ratio
		InputCorrection=1
		while InputCorrection==1:
			try:
				#CODE#
				#Tap Ratio
				print 'Enter TAP Ratio value(1,2,4,8)'
				Tap_ratio_Value_var = input("")
				#Finish Tap Ratio
				#EO CODE#
				InputCorrection=0
			except:
				print "ERROR: please Enter Correct Tap Ratio Value (1,2,4,8)"
				InputCorrection=1
		#Finish Tap Ratio
		try:
			absolutely_unused_variable = os.system('clear')
		except: 
			absolutely_unused_variable = os.system("cls")
		
		
		
		#Parallel
		
		InputCorrection=1
		while InputCorrection==1:
			try:
				#CODE#
				print 'Enter 1 if you want to use Parallel mode (optional for CORE/CBO):'
				print 'Enter 2 otherwise:'
				
				Parallel_ESPF_var = input("")
				#EO CODE#
				InputCorrection=0
			except:
				print "ERROR: please Enter 1 OR 2"
				InputCorrection=1
		
		if str(Parallel_ESPF_var)=="1":
			Parallel_Value_var="YES"
			
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					#NOA PINS
					print 'Enter 1 if you want to use those Parallel pins:'
					print '	"xxNOA_n__13, xxNOA_n__12, xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8"'
					print 'Enter 2 if you want to use those Parallel pins:'
					print '	"xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8"'
					print 'Enter 3 if you want to use those Parallel pins:'
					print '	"xxNOA_n__9, xxNOA_n__8"'
					print 'Enter 4 if otherwise:'
					Parallel_pins_ESPF_var = input("")
					
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter 1/2/3/4"
					InputCorrection=1
			
			
			if str(Parallel_ESPF_var)=="1":
				parallel_pins="xxNOA_n__13, xxNOA_n__12, xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8"
			elif str(Parallel_ESPF_var)=="2":
				parallel_pins="xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8"
			elif str(Parallel_ESPF_var)=="3":
				parallel_pins="xxNOA_n__9, xxNOA_n__8"
			elif str(Parallel_ESPF_var)=="4":
				
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						print 'Please Enter Parallel Pins in this format (xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8) - Strings in quotes!!!!!'
						parallel_pins = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "ERROR: please Enter the PINs String in quotes"
						InputCorrection=1
					
						
				
			else:
				InputCorrection=1
				while InputCorrection==1:
					try:
						#CODE#
						print 'Please Enter Parallel Pins in this format (xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8) - Strings in quotes!!!!!'
						parallel_pins = input("")
						#EO CODE#
						InputCorrection=0
					except:
						print "ERROR: please Enter the PINs String in quotes"
						InputCorrection=1
				
			
		elif str(Parallel_ESPF_var)=="2":
			Parallel_Value_var="NO"
			#NOA PINS default
			parallel_pins="xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8"
		else:
			Parallel_Value_var="NO"
			#NOA PINS default
			parallel_pins="xxNOA_n__11, xxNOA_n__10, xxNOA_n__9, xxNOA_n__8"
			
		#Finish Parallel
		try:
			absolutely_unused_variable = os.system('clear')
		except: 
			absolutely_unused_variable = os.system("cls")
		
		
		#tap_spec
		InputCorrection=1
		while InputCorrection==1:
			try:
				#CODE#
				print 'Enter 1 for tap_spec Value = spf_tap_architecture.spfspec(the file should be contain in your main folder)'
				print "Enter 2 for tap_spec Value = $ENV{'SPF_TAP_SPEC_FILE'}"
				print "Enter 3 for tap_spec Value = $ENV{'SPF_SPEC_FILE'}"
				print 'Enter 4 otherwise:'
				tap_spec_ESPF_var = input("")
				#EO CODE#
				InputCorrection=0
			except:
				print "ERROR: please Enter 1/2/3/4"
				InputCorrection=1
		
		if str(tap_spec_ESPF_var)=="1":
			tap_spec_Value_var="spf_tap_architecture.spfspec"
		elif str(tap_spec_ESPF_var)=="2":
			tap_spec_Value_var="$ENV{'SPF_TAP_SPEC_FILE'}"
		elif str(tap_spec_ESPF_var)=="3":
			tap_spec_Value_var="$ENV{'SPF_SPEC_FILE'}"
		elif str(tap_spec_ESPF_var)=="4":
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					print 'Please Enter tap_spec Value'
					tap_spec_Value_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please tap_spec Value in quotes"
					InputCorrection=1
			
		else:
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					print 'Please Enter tap_spec Value (spf_tap_architecture.spfspec, the file should be contain in your main folder)'
					tap_spec_Value_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please tap_spec Value in quotes"
					InputCorrection=1
		#Finish tap_spec
		
		try:
			absolutely_unused_variable = os.system('clear')
		except: 
			absolutely_unused_variable = os.system("cls")
		
		
		
		
		#GT_Config
		
		InputCorrection=1
		while InputCorrection==1:
			try:
				#CODE#	
				print 'Enter 1 if you want to enter IA config:'
				print 'Enter 2 if you want to enter GT config:'
				print 'Enter 3 if you want to enter DE config:'
				IA_GT_DE_ESPF_var = input("")
				#EO CODE#
				InputCorrection=0
				
			except:
				print "ERROR: please Enter 1/2/3"
				InputCorrection=1	
		if str(IA_GT_DE_ESPF_var)=="1":
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					print 'Please enter Reset Valuse for reset Register (mostly 1 OR 0 )'
					Reset_Value_var = str(input(""))
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter 1 OR 0"
					InputCorrection=1	
			
			
			#defult
			Enable_Value_var="1"
			GT_Config_Value_var="0000"
			
		elif str(IA_GT_DE_ESPF_var)=="2":
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					#Reset
					print 'Please enter Reset Valuse for reset Register (mostly 1 OR 0 )'
					Reset_Value_var = input("")
					#Enable_Value value
					print 'Enter ENABLE Value(mostly 1 OR 0 )'
					Enable_Value_var = input("")
					#GT_Config value
					print 'Enter GT_Config, JUST FOR GT CHAINS ("1111","0000") - Strings in quotes!!!!!'
					GT_Config_Value_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter Correct Values"
					InputCorrection=1
					
		elif str(IA_GT_DE_ESPF_var)=="3":
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					#Reset
					print 'Please enter Reset Valuse for reset Register (mostly 1 OR 0 )'
					Reset_Value_var = input("")
					#Enable_Value value
					print 'Enter ENABLE Value(mostly="1")'
					Enable_Value_var = input("")
					#defult
					GT_Config_Value_var="0000"
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter Correct Values"
					InputCorrection=1
		else:
			InputCorrection=1
			while InputCorrection==1:
				try:
					#CODE#
					print 'Please enter Reset Valuse for reset Register (mostly 1 OR 0 )'
					Reset_Value_var = input("")
					#Enable_Value value
					print 'Enter ENABLE Value(mostly="1")'
					Enable_Value_var = input("")
					#GT_Config value
					print 'Enter GT_Config, JUST FOR GT CHAINS ("1111","0000")'
					GT_Config_Value_var = input("")
					#EO CODE#
					InputCorrection=0
				except:
					print "ERROR: please Enter Correct Values"
					InputCorrection=1
					
		#Finish GT_Config
		
		try:
			absolutely_unused_variable = os.system('clear')
		except: 
			absolutely_unused_variable = os.system("cls")
		

		
		
	
		
		for i in range(0, len(OSC_For_TAP[iterating_var])):
		
			#PRINTING ESPF
			#Folder_ESPF_INPUT=Current_Folder+'/ESPF/'
			#ESPF_NAME = Current_Folder+'/ESPF/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'.espf'
			#ESPF_FOR_SOURCE = './ESPF/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'.espf'
			
			Folder_ESPF_INPUT='./ESPF/'
			ESPF_NAME = './ESPF/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'.espf'
			ESPF_FOR_SOURCE = './ESPF/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'.espf'
			
			if not os.path.exists(Folder_ESPF_INPUT):
				os.makedirs(Folder_ESPF_INPUT)
				ESPF_IDV_Input_file = open (ESPF_NAME, 'w')
			else:
				ESPF_IDV_Input_file = open (ESPF_NAME, 'w')
			
			
			
			SPF_Folder='./SPF/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'/'
			SPF_NAME='./SPF/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'.spf'
			SPF_NAME_FOR_VAULT=Current_Folder+'/SPF/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'/'+iterating_var+'_'+OSC_For_TAP[iterating_var][i]+'_'+DATE+'.spf'
			if not os.path.exists(SPF_Folder):
				os.makedirs(SPF_Folder)
			
			to_print='use SPF::Filter;\n'+'use lib "./bin";\n'+'use IDV_test;\n'+'use lib "./icg_input";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $chain = "'+CHAIN_VAR+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $chain_focus = "'+CHAIN_FOCUS+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $osc = '+OSC_For_TAP[iterating_var][i]+';'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $Fublet_Template_input = "'+FUBLET_Template_INPUT+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $tap_spec = "'+tap_spec_Value_var+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $tap_ratio = '+str(Tap_ratio_Value_var)+';'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $Control_Register = "'+CTL_REG_NAME+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $Reset_Register = "'+Reset_Register_var+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $CounterA_Register = "'+CounterA_Register_var+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $CounterB_Register = "'+CounterB_Register_var+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $CounterALL_Register = "'+CounterALL_Register_var+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $parallel = "'+Parallel_Value_var+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $parallel_pins = "'+parallel_pins+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			
			to_print='my $Reset_Value = "'+str(Reset_Value_var)+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $Enable_Value = "'+str(Enable_Value_var)+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			
			to_print='my $GT_Config = "'+str(GT_Config_Value_var)+'";'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			
			to_print='IDV_test::IDV_test($chain, $osc, $chain_focus,$tap_ratio, $tap_spec,$Fublet_Template_input,$Reset_Register,$CounterA_Register,$CounterB_Register,$CounterALL_Register , $Control_Register,$GT_Config,$parallel,$Reset_Value,$Enable_Value,$parallel_pins);'
			ESPF_IDV_Input_file.write(to_print)
			ESPF_IDV_Input_file.write('\n')
			ESPF_IDV_Input_file.write('\n')
			
			#Close ESPF File
			ESPF_IDV_Input_file.close()
			
			#Write ESPF to SPF for the specific ESPF
			ESPF_TO_SPF_print="$SPF_ROOT/bin/spf_perl_pp --testSeqFile "+ESPF_FOR_SOURCE+" > "+SPF_NAME
			ESPF_TO_SPF_Source_IDV_Input_file.write(ESPF_TO_SPF_print)
			ESPF_TO_SPF_Source_IDV_Input_file.write('\n')
			
			#Write SPF Path for the specific SPF
			Vault_To_print=SPF_NAME_FOR_VAULT
			SPF_FOR_Vault_Input_file.write(Vault_To_print)
			SPF_FOR_Vault_Input_file.write('\n')
			
		
		
		
		
		
		
		
	
###########################Creating ESPF files,SPF FOLDERS,source file with ESPF to SPF,Vault File with SPFs Full PAth#########################################	
	

#print len(OSC_For_TAP)
SPF_FOR_Vault_Input_file.close()
ESPF_TO_SPF_Source_IDV_Input_file.close()
raw_input("File Creation Done,  press enter to exit")	

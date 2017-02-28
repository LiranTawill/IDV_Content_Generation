#####################################################
#	IDV test for KBL
#	Ricard Menchon Enrich, 07/2015, 01/2016
#	Rev 1
#####################################################
package IDV_test;					# SPF pluggin
use IDV_LIB;					# Contains the IDV TAP command functions
use lib $ENV{SPF_PERL_LIB};
use SPF;
use SPF::Filter;

sub IDV_test{
	my ($chain, $osc, $chain_focus,$tap_ratio, $tap_spec,$Fublet_Template_input,$Reset_Register,$CounterA_Register,$CounterB_Register,$CounterALL_Register , $Control_Register,$GT_Config,$parallel,$Reset_Value,$Enable_Value) = @_;

	### API gets all tap spec file:
	my $spec = SPF::Spec->new ($tap_spec);
	
	###### I get the TAPspec of my chain
  	my $tap = $spec->get_tap ($chain_focus); #This has to be out of the "if" otherwise it doesn't go to the other 
	
	###### I get any prepad that could impact the TDI bits.
	###### No need unless using directly pass itpp. Otherwise SPF adds them already!
	
	my $dr_prepad_bits = "";
	if ($tap->has_taplink){
		$dr_prepad_bits = '0'x($tap->get_taplink_pre_dr_delay);
		if ($dr_prepad_bits ne ""){
			$dr_prepad_bits = $dr_prepad_bits."_";
		}
	} 

	
	
	
	###### Fublet info that will be used in several functions
	my %fub = IDV_SPEC_PARSER::IDV_SPEC($Fublet_Template_input); #return all the fublets in hash(Fublet->[Fublet_type(like mif),         Power gate(bool,T/F), Bypass(bit,0/1)])

	###################################################################################################################################################
	###################################################################################################################################################	

	####### Here starts the spf:
	####### If NOA we have to specigy the appropriate pins and delay:
	if ($parallel=~"yes"){
		print "construct itpp pscan_pin_group ".$parallel_pins.";\n";  # Example: In KBL, if we work with CBO or CORE, we will be reading out data through NOA, here we define which ones.
		my $postpad_dr = $tap->get_taplink_post_dr_delay; #gets the postpad dr due to the tap link. To add in in the next line to set the appropriate delay in the NOA captur
		@set tap_pscan_delay $postpad_dr; # to set NOA as it was in legacy.
   	} 
	
	
	focus_tap $chain_focus;
	IDV_LIB::LABEL("IDV_".$chain_focus."_TEST;");
	cycle 300;
	flush;
	
	#Here we will do the reset function - 
	IDV_LIB::Chain_Reset($chain,$Reset_Register,$tap_ratio,$GT_Config,$chain_focus,$tap,$Reset_Value,$Enable_Value);
	#This will enter to the reset including IA reset and GT config (select slice/Unslice)
	

	
	
	
	#IDV_LIB::BYPASS_and_FLUSH($chain, $tap, $chain_focus, %fub); #find the bypass fublets,update them with 0s,and the idv fublets with 1, and flush all address to 00000 and update the counters to 00000000000000.
	
	
	
	
	
	
	my $osc_val = 0;#The previous OSC that tested , Indicate that its the first time that we using the OSC and we need to shift the address and not shift 00000
	my $noosc_tot = 0;#for all OSCs
	#my $osc;   #the OSC from input
	my $noosc_after1fub = 0;#for specipic OSC
	foreach my $fublet (IDV_LIB::FUBLETS($Control_Register,$tap, %fub)){ #Fublets in chain through TAP spec file or the two folders above. Fub instance name,Only fublets that we use(1 in bypass or 11)
		my ($fub_contains_osc, @banks) = IDV_LIB::FUB_CONTAINS_OSC($fublet, $osc,%fub);#return 1 if the OSC is in the list of fublet OSCs, & the Banks (A,B) or just A/B 
			
			
			#pass itpp "Debuggggggggggggggggggggggg";
			#pass itpp "$fublet";
			#pass itpp "$fub_contains_osc";
			#pass itpp "$fub{$fublet}[1]";
			#pass itpp "Debuggggggggggggggggggggggg";
			
		if (!$fub_contains_osc){
			$noosc_after1fub += $fub{$fublet}[1]; #fublet without the OSC that we will shift 5 0s X number of fublets to ignore them
			$noosc_tot += $fub{$fublet}[1];#TOT fublet without the OSC that we will shift 5 0s X number of fublets to ignore them	
			pass itpp "rem: comment:  Skiping fublet $fublet ($fub{$fublet}[0]) for oscillator $osc ;";#we dont want to test this OSC in this Fublet so we skip him.
		}else{ 
			if ($osc != $osc_val){
				IDV_LIB::ADDRESS($Control_Register, $osc, $fublet, $tap, $chain_focus, $noosc_after1fub, $noosc_tot, %fub); #first time need adress all the other we need to push it.
			}else{
				IDV_LIB::SHIFT5($Control_Register, $osc, $fublet, $parallel, $tap, $chain_focus, $dr_prepad_bits, $noosc_after1fub, $noosc_tot, %fub); ### this could be improved to skip more than 5 for fublets that don't have such oscillators. But this is more clear, osc numbers, etc.
			}
			$osc_val = $osc; # I keep the osc address for the if before, so if I repeat the osc, I just shift 5, I don't reshift the address.
			$noosc_after1fub = 0; # We restart this for the next fublet once we already shifted the extra zeros not to add 2 IDVCTL or more together.	
			$noosc_tot = 0;# if its here its not for all. and tot-after=0 always
			###For debug
			#pass itpp "==> INFO: $fublet, $osc, $fub_contains_osc, @banks;";
			####
			
		#	IDV_LIB::LABEL("START_OSC_".$fublet."_".$fub{$fublet}[0]."_".$osc.";");
		#	pass itpp "expandata:xxTCK, 1;";	
		#	cycle 2;
		#	flush;
		#	pass itpp "expandata:xxTCK, $tap_ratio;";				

			IDV_LIB::WAIT_MEASURE($fublet,$osc,$tap_ratio,%fub,$chain_focus); #fublet and osc needed for the label.
			IDV_LIB::CAPTURE_COUNTER($tap,$chain,$Control_Register,$CounterA_Register,$CounterB_Register,$CounterALL_Register,$fublet,$osc,$parallel, $chain_focus,@banks); 	#need to fublet and osc to know if there is B, or A and B counters. 
			IDV_LIB::WAIT_AFTER($tap_ratio);
		}
	}
		
	IDV_LIB::FLUSH_STOP_END($chain,$Control_Register,$CounterALL_Register, $chain_focus,$tap);
	#HDMT learning - without it we wont have exactly 100 wait in the capture for the last OSC. 
	IDV_LIB::LABEL("IDV_".$chain_focus."_TEST_End;");
	cycle 200;
	flush;
}
1;

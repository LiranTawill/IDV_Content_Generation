#####################################################
#	IDV_LIB_for_IDV_test_KBL
#	Ricard Menchon Enrich, 04/02/2016
#	Rev 2
#####################################################
package IDV_LIB;

use SPF::Filter;
use IDV_SPEC_PARSER;



sub LABEL {
my ($label) = @_;
pass itpp "label: $label";
};


sub Chain_Reset{#before we running GT preperation 
	my ($chain,$Reset_Register,$tap_ratio,$GT_Config,$chain_focus,$tap) = @_;
	IDV_LIB::LABEL("IDV_RESET_for_".$chain_focus.";");
	
	#if ($parallel=~"yes"){
	#	print "construct itpp pscan_pin_group ".$parallel_pins.";\n";  # Example: In KBL, if we work with CBO or CORE, we will be reading out data through NOA, here we define which ones.
	#	my $postpad_dr = $tap->get_taplink_post_dr_delay; #gets the postpad dr due to the tap link. To add in in the next line to set the appropriate delay in the NOA captur
     #           @set tap_pscan_delay $postpad_dr; # to set NOA as it was in legacy.
   	#} 
	
	if ($chain eq "IA"){
		my $IDV_Reset_Register = $tap->get_register ($Reset_Register);
		my @list_aliases = SPF::Alias::sort($IDV_Reset_Register->get_each_alias);#all the bit names from spec
		my @list_Reset_aliases_names;
		foreach my $alias (@list_aliases){
        	push (@list_Reset_aliases_names, $alias->get_name); #### Sorted fub_instances in the tap_spec file
		}
		
		foreach my $alias (@list_Reset_aliases_names){
        	set $Reset_Register->$alias = 'b1; #'
		}
		flush;
	}	
	else{#GT or DE
		my $IDV_Reset_Register = $tap->get_register ($Reset_Register);
		my @list_aliases = SPF::Alias::sort($IDV_Reset_Register->get_each_alias);#all the bit names from spec
		my @list_Reset_aliases_names;
		foreach my $alias (@list_aliases){
        	push (@list_Reset_aliases_names, $alias->get_name); #### Sorted fub_instances in the tap_spec file
		}
		foreach my $alias (@list_Reset_aliases_names){
        	
			if ($alias =~ "reset" or $alias =~ "enable" ){
				set $Reset_Register->$alias = 'b1; #'
			}
			elsif($alias =~ "slice_select"){
				set $Reset_Register->$alias = 'b'.$GT_Config.'1; #'
			}
		}
		flush;
	}
	if ($tap_ratio ne "1"){
		IDV_LIB::Tap_Ratio($tap_ratio);
		#pass itpp "expandata:xxTCK, $tap_ratio;";
	}
	
}1;
sub Tap_Ratio{
	my ($tap_ratio) = @_;
	IDV_LIB::LABEL("TAP_Ratio_1_".$tap_ratio.";");#change ratio of Fsm clk in gt(in pattern if its 1.2 so it wll be 2 Nops instead of 1)
	pass itpp "expandata:xxTCK, $tap_ratio;";
	cycle 10;#IDLE the FSM FOR 10 Cycle
}1;
	
	
sub GTPREP{#before we running GT preperation 
	my ($tap_ratio) = @_;
	#I'll work with BYPASS for the moment, so I don;t have problems with the leakage osc. It didn't give data only with the Bypass. Maybe Bypass had to be before DFXMECHANISM?
	##IDV RESET for GT. Turn on all IDV fublets. For all slices!
	IDV_LIB::LABEL("IDV_RESET_for_GT;");
	set GT_ECOTAPRESERVEDTAPCLKONLY->TAP_IDVRST_MCP  = 'b1;  ####'
	flush;

	#DFX config for power
	IDV_LIB::LABEL("GT_DFXCONFIGURATIONMECHANISM_config_for_power;");
	set GT_DFXCONFIGURATIONMECHANISM->DATA = 'b00000000000000000000000000000010;#'
	set GT_DFXCONFIGURATIONMECHANISM->ADDRESS = 'b000000000000001101001100;#'
	set GT_DFXCONFIGURATIONMECHANISM->BYTE_EN_B = 'b0000;#'
	set GT_DFXCONFIGURATIONMECHANISM->TSID = 'b00;#'
	set GT_DFXCONFIGURATIONMECHANISM->T3ID = 'b00;#'
	set GT_DFXCONFIGURATIONMECHANISM->TUID = 'b0000000;#'
	set GT_DFXCONFIGURATIONMECHANISM->MANUAL_ID_EN = 'b0;#'
	set GT_DFXCONFIGURATIONMECHANISM->CFGSRC = 'b11;#'
	set GT_DFXCONFIGURATIONMECHANISM->CFGOP = 'b001;#'
	set GT_DFXCONFIGURATIONMECHANISM->NPSEL = 'b0;#'
	set GT_DFXCONFIGURATIONMECHANISM->MULTICAST = 'b1;#'
	set GT_DFXCONFIGURATIONMECHANISM->MBPEN = 'b0;#'
	flush;

	## JF solution. Actually they are missing lots of bits!!!! they add 52 bits, but the register has 81!!!
	#tap_raw_shift : ir_tdi = GT_DFXCONFIGURATIONMECHANISM,
	#        dr_tdi = 'b0100011100000000000000000000000000000011010011000000;  #'
	#flush;

	#Long chain selection:
	IDV_LIB::LABEL("GT_Long_chain_selection;");
	set GT_IDVRTDOCONTROL->GDT_IDVUNSLICE_SMALL_CHAIN = 'b1; #' #take the long chain
	set GT_IDVRTDOCONTROL->GDT_IDVSLICE_SMALL_CHAIN = 'b1; #'#take the long chain
	flush;

	
	#TAP ratio depending on chain
	IDV_LIB::LABEL("TAP_Ratio_1_".$tap_ratio.";");#change ratio of Fsm clk in gt(in pattern if its 1.2 so it wll be 2 Nops instead of 1)
	pass itpp "expandata:xxTCK, $tap_ratio;";

	cycle 10;#IDLE the FSM FOR 10 Cycle
}1;



sub FUBLETS{ #Fub instance names extracted before for NON-BYPASSED FUBLETS.
	my ($Control_Register,$tap, %fub) = @_;
	
	my $ControlRegister = $Control_Register;
	
	
	#my %fub = IDV_SPEC_PARSER::BYPASS_IDV_SPEC($chain, $chain_focus); ##### NOT IN ORDER!!!! SO we order them:
	my ($fublet_order_ref) = IDV_SPEC_PARSER::CONTROL_TAP_SPEC($ControlRegister, $tap, %fub); ### ALL FUBLETS IN ORDER
	my @fublet_order = @$fublet_order_ref;
	my @fublet;
	
	
	
	foreach my $fub_instance (@fublet_order){ #### INCLUDE ONLY NON-BYPASSED FUBLETS
		push (@fublet, $fub_instance);
	}
	
	return @fublet;

	#FOR DEBUG:
		#printf "Fublet ORDER: @fublet_order\n";
		#printf "FUBLET: @fublet\n";
};



sub ADDRESS{  #chech the before and after
	my ($Control_Register, $osc, $fublet, $tap, $chain_focus, $noosc_after1fub, $noosc_tot, %fub) = @_;
	my $IDVCTL=$Control_Register;
	
	
	my $DUMMY_HI_BITS = IDV_SPEC_PARSER::RETURN_DUMMY_HI_REG($IDVCTL, $tap);#How much Dummy high bits
	my $noosc_after1fub_bits = '0' x (5*$noosc_after1fub);
	my $noosc_before1fub_bits = '0' x (5*($noosc_tot - $noosc_after1fub));
	my $OSC_DR = "'b".$DUMMY_HI_BITS.$noosc_after1fub_bits."_".reverse(split(//,sprintf ("%05b",$osc))).$noosc_before1fub_bits;#."_00";  #Converts osc number to binary with 5 digits, splits it in an array, reverses the array (bits), And I add the DummyHigh_b'oscreversed(_DummyLow). I decided to skip DUMMY_LOW, not important for TDI.
	
	IDV_LIB::LABEL("IDVCTL_osc_address_".$osc."_".$chain_focus."_".$fublet."_".$fub{$fublet}[0].";");
	tap_raw_shift : 
		ir_tdi = $IDVCTL,
		dr_tdi = $OSC_DR; #example 'b00_10000 dummyhigh_invertedadress. Actually, from spec should be b00_10000_00 dummyhigh_invertedadress_dummylow, but dummylow doesn't play any role to set the right position for the osc.
	flush;
}1;



sub SHIFT5{
	my ($Control_Register, $osc, $fublet, $parallel, $tap, $chain_focus, $dr_prepad_bits, $noosc_after1fub, $noosc_tot, %fub) = @_;
	#my %fub = IDV_SPEC_PARSER::BYPASS_IDV_SPEC($chain, $chain_focus);


	my $IDVCTL=$Control_Register;
	
	

	#@set tap_skip_dr_back_padding on;
	#IDV_LIB::LABEL("IDVCTL_shift5_address;");#.$chain."_".$fublet.";"); 
	#tap_raw_shift : 
	#	ir_tdi = $IDVCTL, dr_tdi = 'b00000; #####' 
	#flush;
	#@set tap_skip_dr_back_padding off;
	#pass itpp " ";
	
	### OLD WAY TO ADD THE 5 bit SHIFT when there was no @set tap_skip_dr_back_padding on/off.
	##### NOT ALL CHAINS HAVE TAP_LINK (SA doesn't have it).
	IDV_LIB::LABEL("IDVCTL_shift_zeros_".$fublet."_".$fub{$fublet}[0]."_".$osc.";"); 
        tap_raw_shift : 
        	ir_tdi = $IDVCTL; 
	flush;
######DR##############
	my ($startchain,$LINK_DR) = IDV_SPEC_PARSER::TAP_LINK_DR($parallel, $tap);
	if ($startchain == 1) { ##### IF the chain doesn't have TAP_LINK, this is not executed
		pass itpp "scani: $LINK_DR ;"; # LINK_DR is the appropriate opcode taken from the spec with the IDV_SPEC_PARSER
		pass itpp "to_state: Run-Test/Idle ;";
	}
	my $shift5tdi;
	my $shift5tdo;
#	if ("$fub{$fublet}[0]" =~ "lkg"){
#		$shift5tdi = $dr_prepad_bits."0000000000"; #####'
#		my $c = () = $shift5tdi =~ /0/g;	
#		$shift5tdo = 'X' x $c; 
#	}else{
		my $noosc_after1fub_bits = '0' x (5*$noosc_after1fub);
		my $noosc_before1fub_bits = '0' x (5*($noosc_tot - $noosc_after1fub));
		$shift5tdi = $dr_prepad_bits.$noosc_after1fub_bits."00000".$noosc_before1fub_bits; #####'
		my $c = () = $shift5tdi =~ /0/g;	
		$shift5tdo = 'X' x $c; 
#	}
	pass itpp "scand: $shift5tdi, $shift5tdo ;";
	pass itpp "to_state: Run-Test/Idle ;";
	pass itpp " ";
}1;


sub FUB_CONTAINS_OSC{  ###### Not all fublets contain all oscillators.
	my ($fublet, $osc,%fub) = @_;
	#my %fub = IDV_SPEC_PARSER::BYPASS_IDV_SPEC($chain, $chain_focus);

	
	open (fublet_contains, "./bin/fublet_contains.txt") or die 'Could not open file ', "fublet_contains.txt", ": $!"; 	#open fublet_contains.txt file that I created for 1272
	my $return1 = 0;
	my @banks = ();
	
	foreach my $line (<fublet_contains>){
		chomp $line;
		my @fub_type = $line =~ /^(.*)\t.*$/;    	### From the fublet_contains.txt file, for each line, we extract the fun type: mif, ana, spd, etc...
		my @osc_in_line = $line =~ /.*\|(.*)/;
		@osc_in_line = split (",", $osc_in_line[0]);
		$fub_type[0] =~ s/\s//g;					#### Clean the fub_type from any tab or space that would make the following if to fail.
		$fub_type[0] =~ s/\t//g;

		if ("$fub{$fublet}[0]_end" =~ "$fub_type[0]_end"){		### Then we check if that type matches the type of fublet we are currently on the chain. "_end" added in order to match the end of the string and not mix "mif" with "mif2".
			#pass itpp "matched;";
			if ($osc ~~ @osc_in_line){				### If it matches, we check if this fublet has the oscillator we are running. No problem with mif2 and mif3 having numbers in their name, as we only compare with the second part of the line, where only osc numbers are, no fub types.
				$return1 = 1;							### if the oscillator is in the line, we are good, and we return 1. We will wait and capture the result.
				my @bank = $line =~ /^.*\t(.*)\|.*$/;
				push (@banks, @bank[0]);#Bank A or Bank B
			} 
		}
	}
	close(fublet_contains);

	###For debug
	#pass itpp "==> INFO: $fublet, $fub{$fublet}[0], @banks";
	####
	
	if ($return1 == 1){
		return (1,@banks);
	}else{
		return (0,0);
	}
};

sub WAIT_MEASURE{
	my ($fublet, $osc, $tap_ratio, %fub) = @_;
	if ($tap_ratio ne "1"){
		IDV_LIB::Tap_Ratio(1);
	}
	IDV_LIB::LABEL("WAIT_OSC_".$fublet."_".$fub{$fublet}[0]."_".$osc."_LEG:;");
	cycle 100;
	flush;
	if ($tap_ratio ne "1"){
		IDV_LIB::Tap_Ratio($tap_ratio);
	}
	pass itpp " ";
}1;

sub CAPTURE_COUNTER{ #Need to select the appropriate banks
	my ($chain,$Control_Register,$CounterA_Register,$CounterB_Register,$CounterALL_Register,$fublet,$osc,$parallel, $chain_focus,@banks) = @_;
	
	if ($parallel =~ "yes"){  ##### CORE and CBO chains that work in parallel and shift data out through NOA for KBL check for ICL
		if (($#banks + 1) == 2){
			$IDVCNTR = $CounterALL_Register;
			##print "$chain";	
			### Through NOA
			#### here there will be the pscand
			@set tap_pscan_mode on;
			IDV_LIB::LABEL("CAPTURE_RESULTS_".$IDVCNTR."_".$fublet."_".$osc."_LEG:;");
			compare  $IDVCNTR->COUNTERA.VALUE  = 'b00000000000000; #####'
			capture  $IDVCNTR->COUNTERA.VALUE;
			mask  $IDVCNTR->COUNTERA.VALUE;		
			compare  $IDVCNTR->COUNTERB.VALUE  = 'b00000000000000; ##### '
			capture  $IDVCNTR->COUNTERB.VALUE;
			mask  $IDVCNTR->COUNTERB.VALUE;
			flush;			
			@set tap_pscan_mode off;
			
		}else {
			if($banks[0]=~"A"){$IDVCNTR = $CounterA_Register;}
			else{$IDVCNTR = $CounterB_Register;}
			  ##### $banks[0] is equal to either A or B
			
			### Through TDO: at the moment while there is no pscand (just to see how it would look like).
			@set tap_pscan_mode on;
			IDV_LIB::LABEL("CAPTURE_RESULTS_".$IDVCNTR."_".$fublet."_".$osc."_LEG:;");
			compare  $IDVCNTR->COUNTER.VALUE  = 'b00000000000000; ###' 
			capture  $IDVCNTR->COUNTER.VALUE;
			mask  $IDVCNTR->COUNTER.VALUE;
			flush;
			@set tap_pscan_mode off;			
		}		
	}else{ ##### chains that use TDO to capture the data
		if (($#banks + 1) == 2){
			if ($chain eq "GT_DE"){
				$IDVCNTR = $CounterALL_Register;
				IDV_LIB::LABEL("CAPTURE_RESULTS_".$IDVCNTR."_".$fublet."_".$osc."_LEG:;");
				compare $IDVCNTR-> counterb_result  = 'b0000000000000; #'
				capture $IDVCNTR-> counterb_result;
				mask $IDVCNTR-> counterb_result;
				compare $IDVCNTR-> counterb_ovf  = 'b0; #'
				capture $IDVCNTR-> counterb_ovf;
				mask $IDVCNTR-> counterb_ovf;
				compare $IDVCNTR-> countera_result = 'b0000000000000;#'
				capture $IDVCNTR-> countera_result;
				mask $IDVCNTR-> countera_result;
				compare $IDVCNTR-> countera_ovf  = 'b0; #'
				capture $IDVCNTR-> countera_ovf;
				mask $IDVCNTR-> countera_ovf;
				flush;

			}else{
				$IDVCNTR = $CounterALL_Register;
				IDV_LIB::LABEL("CAPTURE_RESULTS_".$IDVCNTR."_".$fublet."_".$osc."_LEG:;");
				
				
			
				
				
				
				my $COUNTERA;
				my $COUNTERB;
				if ($chain_focus eq "EFLOW"){
					$COUNTERA = "COUNTER_A";
					$COUNTERB = "COUNTER_B";
				}else{
					$COUNTERA = "CounterA.value";
					$COUNTERB = "CounterB.value";
				}
				compare  $IDVCNTR->$COUNTERA  = 'b00000000000000; ####'
				capture  $IDVCNTR->$COUNTERA;
				mask  $IDVCNTR->$COUNTERA;		
				compare  $IDVCNTR->$COUNTERB  = 'b00000000000000; ##### '
				capture  $IDVCNTR->$COUNTERB;
				mask  $IDVCNTR->$COUNTERB;
				flush;
			}
		
		}else {
			if ($chain eq "GT_DE"){
				if($banks[0]=~"A"){$IDVCNTR = $CounterA_Register;}
				else{$IDVCNTR = $CounterB_Register;}
				
				IDV_LIB::LABEL("CAPTURE_RESULTS_".$IDVCNTR."_".$fublet."_".$osc."_LEG:;");
				compare $IDVCNTR-> counter  = 'b0000000000000; #'
				capture $IDVCNTR-> counter;
				mask $IDVCNTR-> counter;
				compare $IDVCNTR-> overflow  = 'b0; #'
				capture $IDVCNTR-> overflow;
				mask $IDVCNTR-> overflow;
				flush;
				
			}else{	
				if($banks[0]=~"A"){$IDVCNTR = $CounterA_Register;}
				else{$IDVCNTR = $CounterB_Register;}
				
				IDV_LIB::LABEL("CAPTURE_RESULTS_".$IDVCNTR."_".$fublet."_".$osc."_LEG:;");
				my $COUNTER= "counter.value";
				compare  $IDVCNTR->$COUNTER  = 'b00000000000000; ####'
				capture  $IDVCNTR->$COUNTER;
				mask  $IDVCNTR->$COUNTER;                      
				flush;
			}
		}
	}
	
}1;

sub WAIT_AFTER {
	my ($tap_ratio) = @_;
	if ($tap_ratio ne "1"){
		IDV_LIB::Tap_Ratio(1);
		#pass itpp "expandata:xxTCK, 1;";
	}
	IDV_LIB::LABEL("WAIT_after_measuring;");
	cycle 10;
	flush;
	if ($tap_ratio ne "1"){	
		IDV_LIB::Tap_Ratio($tap_ratio);
		#pass itpp "expandata:xxTCK, $tap_ratio;";
	}
	pass itpp " ";
}1;


sub FLUSH_STOP_END { ## To be sure all addresses are zero when ending the pattern, and counters are stopped.
	my ($chain,$Control_Register,$CounterALL_Register, $chain_focus) = @_;        
	#flush 2 more fublets just for be safe.
	IDV_LIB::LABEL("END_FLUSH_10_".$chain.";");
	my $IDVCTL = $Control_Register;
	tap_raw_shift :
	ir_tdi = $IDVCTL,
	dr_tdi = 'b0000000000; #'
	flush;

	IDV_LIB::LABEL("DUMMY_IDVCNTR_TO_STOP_CLEAN_COUNTERS_".$chain_focus.";");
	my $IDVCNTR = $CounterALL_Register; 
	if ($chain eq "GT_DE"){#stop the counters
		set $IDVCNTR-> counterb  = 'b0000000000000; #'
		set $IDVCNTR-> counterb_overflow  = 'b0; #'
		set $IDVCNTR-> countera  = 'b0000000000000; #'
		set $IDVCNTR-> countera_overflow  = 'b0; #'
		flush;
	}else{
		my $COUNTERA;
		my $COUNTERB;
		if ($chain_focus eq "EFLOW"){
			$COUNTERA = "COUNTER_A";
				$COUNTERB = "COUNTER_B";
		}else{
				$COUNTERA = "CounterA.value";
				$COUNTERB = "CounterB.value";
		}
		set $IDVCNTR->$COUNTERA  = 'b00000000000000; ####'
		set $IDVCNTR->$COUNTERB  = 'b00000000000000; ####'
		flush;
	}
}1;

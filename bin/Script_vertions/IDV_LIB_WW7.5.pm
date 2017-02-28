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
	my ($chain,$Reset_Register,$tap_ratio,$GT_Config,$chain_focus,$tap,$Reset_Value,$Enable_Value) = @_;
	IDV_LIB::LABEL("IDV_RESET_for_".$chain_focus.";");
	
	if ($parallel=~"yes"){
		print "construct itpp pscan_pin_group ".$parallel_pins.";\n";  # Example: In KBL, if we work with CBO or CORE, we will be reading out data through NOA, here we define which ones.
		my $postpad_dr = $tap->get_taplink_post_dr_delay; #gets the postpad dr due to the tap link. To add in in the next line to set the appropriate delay in the NOA captur
                @set tap_pscan_delay $postpad_dr; # to set NOA as it was in legacy.
   	} 
	
	if ($chain eq "IA"){
		my $IDV_Reset_Register = $tap->get_register ($Reset_Register);
		my @list_aliases = SPF::Alias::sort($IDV_Reset_Register->get_each_alias);#all the bit names from spec
		my @list_Reset_aliases_names;
		foreach my $alias (@list_aliases){
        	push (@list_Reset_aliases_names, $alias->get_name); #### Sorted fub_instances in the tap_spec file
		}
		
		foreach my $alias (@list_Reset_aliases_names){
			my $IA_reset = "'b".$Reset_Value;
        	set $Reset_Register->$alias = $IA_reset;
			#options to add other bits with if statements 
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
        	
			if ($alias =~ "reset"){
				my $GT_DE_reset = "'b".$Reset_Value;
				set $Reset_Register->$alias = $GT_DE_reset;
			}
			elsif($alias =~ "enable"){
				my $GT_DE_enable = "'b".$Enable_Value;
				set $Reset_Register->$alias = $GT_DE_enable;
			}
			elsif($alias =~ "slice_select"){
				my $GT_Config_select = "'b".$GT_Config;   
				set $Reset_Register->$alias = $GT_Config_select;
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
	
	

sub FUBLETS{ #Fub instance names extracted + Size for ALL FUBLETS in Input file (Defualt enable fublets (IDV,PLL_IDV)).
	my ($Control_Register,$tap, %fub) = @_;
	my $ControlRegister = $Control_Register;
	
	my ($fublet_order_ref) = IDV_SPEC_PARSER::CONTROL_TAP_SPEC($ControlRegister, $tap, %fub); ### ALL FUBLETS IN ORDER
	my @fublet_order = @$fublet_order_ref;
	return @fublet_order;
};



sub ADDRESS{  #check the before and after,
	my ($Control_Register, $osc, $fublet, $tap, $chain_focus, $noosc_after1fub, $noosc_tot, %fub) = @_;
	my $IDVCTL=$Control_Register;
	
	
	my $DUMMY_HI_BITS = IDV_SPEC_PARSER::RETURN_DUMMY_HI_REG($IDVCTL, $tap);#How much Dummy high bits
	my $noosc_after1fub_bits = '0' x ($noosc_after1fub);
	my $noosc_before1fub_bits = '0' x (($noosc_tot - $noosc_after1fub));
	
	
	my $Address_size="%0".$fub{$fublet}[1]."b";#Adress size - in the current IDV address =5 
	
	my $OSC_DR = "'b".$DUMMY_HI_BITS.$noosc_after1fub_bits."_".reverse(split(//,sprintf ($Address_size,$osc))).$noosc_before1fub_bits;#."_00";  #Converts osc number to binary with 5 digits, splits it in an array, reverses the array (bits), And I add the DummyHigh_b'oscreversed(_DummyLow). I decided to skip DUMMY_LOW, not important for TDI.
	
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
	
	
######IR##############	
	IDV_LIB::LABEL("IDVCTL_shift_zeros_".$osc."_".$chain_focus."_".$fublet."_".$fub{$fublet}[0].";"); 
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
	my $Fublet_Zeros_For_Shift= '0' x ($fub{$fublet}[1]);
	my $noosc_after1fub_bits = '0' x ($noosc_after1fub);
	my $noosc_before1fub_bits = '0' x (($noosc_tot - $noosc_after1fub));
	$shift5tdi = $dr_prepad_bits.$noosc_after1fub_bits.$Fublet_Zeros_For_Shift.$noosc_before1fub_bits; #####'
	my $character_lenght = () = $shift5tdi =~ /0/g;	
	$shift5tdo = 'X' x $character_lenght; 
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
	my ($fublet, $osc, $tap_ratio, %fub,$chain_focus) = @_;
	if ($tap_ratio ne "1"){
		IDV_LIB::Tap_Ratio(1);
	}
	IDV_LIB::LABEL("WAIT_OSC_".$chain_focus."_".$fublet."_".$fub{$fublet}[0]."_".$osc."_LEG:;");
	cycle 100;
	flush;
	if ($tap_ratio ne "1"){
		IDV_LIB::Tap_Ratio($tap_ratio);
	}
	pass itpp " ";
}1;

sub CAPTURE_COUNTER{ #Need to select the appropriate banks
	my ($tap,$chain,$Control_Register,$CounterA_Register,$CounterB_Register,$CounterALL_Register,$fublet,$osc,$parallel, $chain_focus,@banks) = @_;
	if (($#banks + 1) == 2){
		$IDVCNTR = $CounterALL_Register;
		IDV_LIB::LABEL("CAPTURE_RESULTS_".$chain_focus."_".$IDVCNTR."_".$fublet."_".$fub{$fublet}[0]."_".$osc."_LEG:;");
		my $IDV_CNTR_Register = $tap->get_register ($IDVCNTR);
		my @list_aliases = SPF::Alias::sort($IDV_CNTR_Register->get_each_alias);#all the bit names from spec
		#@list_aliases= reverse(@list_aliases);#maybe need to remove, only for GT need it
		my %list_CNTR_aliases_names = ();
		my @list_CTL_aliases_names_Loop;
		foreach my $alias (@list_aliases){#take all without Dummys
			my $name = $alias->get_name;
			my $numbits = $alias->get_size;
			my $bits = '0' x $numbits;
			my $Compare_BITS = "'b".$bits;          
			if (!($name =~ m/(dummy.*|DUMMY.*)/)){
				$list_CNTR_aliases_names{$name} =  $Compare_BITS ;
				push (@list_CTL_aliases_names_Loop, $name)
			}
		}
		if ($parallel =~ "yes"){
		@set tap_pscan_mode on;
		}
		foreach my $Field (@list_CTL_aliases_names_Loop){
			compare $IDVCNTR->$Field = $list_CNTR_aliases_names{$Field};
			capture $IDVCNTR->$Field;
			mask  $IDVCNTR->$Field;
		}
		flush;
		if ($parallel =~ "yes"){
		@set tap_pscan_mode off;
		}
		
	}else {
		if($banks[0]=~"A"){$IDVCNTR = $CounterA_Register;}
		else{$IDVCNTR = $CounterB_Register;}
		
		IDV_LIB::LABEL("CAPTURE_RESULTS_".$IDVCNTR."_".$fublet."_".$osc."_LEG:;");
		my $IDV_CNTR_Register = $tap->get_register ($IDVCNTR);
		my @list_aliases = SPF::Alias::sort($IDV_CNTR_Register->get_each_alias);#all the bit names from spec
		#@list_aliases= reverse(@list_aliases);
		my %list_CNTR_aliases_names = ();
		my @list_CTL_aliases_names_Loop;
		foreach my $alias (@list_aliases){#take all without Dummys
			my $name = $alias->get_name;
			my $numbits = $alias->get_size;
			my $bits = '0' x $numbits;
			my $Compare_BITS = "'b".$bits;          
			if (!($name =~ m/(dummy.*|DUMMY.*)/)){
				$list_CNTR_aliases_names{$name} =  $Compare_BITS ;
				push (@list_CTL_aliases_names_Loop, $name)
			}
		}
		
		if ($parallel =~ "yes"){
		@set tap_pscan_mode on;
		}
		foreach my $Field (@list_CTL_aliases_names_Loop){
			compare $IDVCNTR->$Field = $list_CNTR_aliases_names{$Field};
			capture $IDVCNTR->$Field;
			mask  $IDVCNTR->$Field;
		}
		flush;
		if ($parallel =~ "yes"){
		@set tap_pscan_mode off;
		}
		
	}
	
	
}1;

sub WAIT_AFTER {
	my ($tap_ratio) = @_;
	if ($tap_ratio ne "1"){
		IDV_LIB::Tap_Ratio(1);
	}
	IDV_LIB::LABEL("WAIT_after_measuring;");
	cycle 10;
	flush;
	if ($tap_ratio ne "1"){	
		IDV_LIB::Tap_Ratio($tap_ratio);
	}
	pass itpp " ";
}1;


sub FLUSH_STOP_END { ## To be sure all addresses are zero when ending the pattern, and counters are stopped. I need to drop this one. TTR
	my ($chain,$Control_Register,$CounterALL_Register, $chain_focus,$tap) = @_;        
	#flush 2 more fublets just for be safe.
	IDV_LIB::LABEL("END_FLUSH_10_".$chain_focus.";");
	my $IDVCTL = $Control_Register;
	tap_raw_shift :
	ir_tdi = $IDVCTL,
	dr_tdi = 'b0000000000; #'
	flush;

	
	IDV_LIB::LABEL("DUMMY_IDVCNTR_TO_STOP_CLEAN_COUNTERS_".$chain_focus.";");
	my $IDVCNTR = $CounterALL_Register; 
	my $IDV_CNTR_Register = $tap->get_register ($IDVCNTR);
	my @list_aliases = SPF::Alias::sort($IDV_CNTR_Register->get_each_alias);#all the bit names from spec
	#@list_aliases= reverse(@list_aliases);
	my %list_CNTR_aliases_names = ();
	foreach my $alias (@list_aliases){#take all without Dummys
		my $name = $alias->get_name;
		my $numbits = $alias->get_size;
		my $bits = '0' x $numbits;
		my $Compare_BITS = "'b".$bits;          
		if (!($name =~ m/(dummy.*|DUMMY.*)/)){
			$list_CNTR_aliases_names{$name} =  $Compare_BITS ;
		}
	}
	
	for my $Field ( keys %list_CNTR_aliases_names ) {
		set $IDVCNTR->$Field = $list_CNTR_aliases_names{$Field};
	}
	flush;
	
}1;

#####################################################
#	IDV_SPEC_PARSER_for_IDV_test_KBL
#	Ricard Menchon Enrich, 30/07/2015
#	Rev 1
#####################################################
package IDV_SPEC_PARSER;
use lib $ENV{SPF_PERL_LIB};
use SPF;
use SPF::Filter;


sub IDV_SPEC {
	my ($Fublet_Template_input) = @_;
	#################################################################################################################
	#Extracting the IDV fublets from the whole chain. POWER gated do not appear in the IDVBYPASS chain!!! 
	#################################################################################################################	
	my %fub = (); # I need to define it outside the $chain loop if I want to be able to use it later
	my $spec_idv= $Fublet_Template_input;
	
	##### PARSE the IDV global_system_spec file:
	open (spec_idv, $spec_idv) or die 'Could not open file ', $spec_idv, ": $!"; 
	
	foreach my $line (<spec_idv>){
		chomp $line;
		if ($line =~ "idv"){
			my @Fub_Array = split / /, $line;
			my @fub_instance = $Fub_Array[0];	##### get the fub instance. From: "$MODEL_ROOT/cte/dft/global_chain/core_te/spec/client/core_global_system_spec.e"
			my @fub_type = $Fub_Array[1];			##### get the fub type
			#my @fub_pg = $line =~ /powergated\=(FALSE|TRUE)/;				##### get if power gated or not
		
			$fub_instance[0]=~ s/\s//g;$fub_type[0]=~ s/\s//g;				###### remove any possible white space
			$fub{$fub_instance[0]} = [ $fub_type[0]];			##### link them together for afterwards
			
			
			
			#FOR DEBUG
				#pass itpp "$fub_instance[0]";
				#pass itpp "$fub_type[0]";
				#pass itpp "$fub_pg[0]";
				#pass itpp "$fub{$fub_instance[0]}[0]";
				#pass itpp "$fub{$fub_instance[0]}[1]";
				#pass itpp "$fub{$fub_instance[0]}[2]";
				#pass itpp "@{ $fub{$fub_instance[0]} }";
		}
	}
	close(spec_idv);
	return %fub;
	#################################################################################################
};


sub CONTROL_TAP_SPEC {
	my($ControlRegister, $tap, %fub) = @_;
	###### API NEW:
	#can take it with $register->get_each_alias_name; 
	my $IDV_Control_Register = $tap->get_register ($ControlRegister);
	my @list_IDVBYPASS_aliases = SPF::Alias::sort($IDV_Control_Register->get_each_alias);#all the bit names from spec
	my @list_IDVBYPASS_aliases_names;
	foreach my $alias (@list_IDVBYPASS_aliases){
        	push (@list_IDVBYPASS_aliases_names, $alias->get_name); #### Sorted fub_instances in the tap_spec file
	}
	#print "List of alias names: @list_IDVBYPASS_aliases_names\n";
	
	### Order fublets properly:
	my @BYPASS_DR;
	my @fublet_order; #what we will send
	foreach my $alias (@list_IDVBYPASS_aliases_names){  
		$alias =~ s/\..*//g ;
		$alias = $alias."_end";
		for my $fub_instance ( keys %fub ) {
			my $FUBINSTANCE = uc $fub_instance;
			#$alias =~ s/\..*//g ;
			#$alias = $alias."_end";
			$FUBINSTANCE = $FUBINSTANCE."_end";
			#print $FUBINSTANCE;
			if ($FUBINSTANCE ne ""){
				if ($alias =~ $FUBINSTANCE){
					#printf "I'm here! $FUBINSTANCE $alias\n";
					#print "$fub_instance\n";
					#### ADD HERE THE ORDERED FUB SEQUENCE!!!
					push (@fublet_order, $fub_instance);#enter the fub name.
					#push (@BYPASS_DR, ${ $fub{$fub_instance} }[2]);#push the bypass bit from hash.
					last;#break the loop.
				}
			}
		}		
	}
	#print "Fublet order: @fubler_order\n";
	
	#### Final DR:
	my $DUMMY_HI_BITS = RETURN_DUMMY_HI_REG($ControlRegister, $tap); #return how much Dummy Hi bits we have
	##### Fix the chain order
	#my $IDVBYPASS_DR = "'b".$DUMMY_HI_BITS."_".join("", reverse(@BYPASS_DR)); ##reverse because of the push
	@fublet_order = reverse(@fublet_order); # reverse because of the push
	#############################################################	
	return (\@fublet_order);
};



sub FLUSH_TAP_SPEC{
	my($IDVBYPASS_DR,$IDVCTL, $tap) = @_;
	
	#################Take the number of ones in the previous register and use it here as number of zeros to shift*5, plus dummies (TAP LINK will add automatically). Maybe need to add some other zero, check GT SKL IDV as an example.
	my $FLUSH_bits = 0;
	foreach my $add (split('', $IDVBYPASS_DR)) {$FLUSH_bits += $add; } #### We take each fublet activated
	$FLUSH_bits *= 5;	############ and we multiply by 5, as we want to fill the 5 bit registers in each fublet with zeros.
	#printf "$FLUSH_bits\n";
	###################################

	my $DUMMY_HI_BITS = RETURN_DUMMY_HI_REG($IDVCTL, $tap);#return how much dummy high we have
	
	my $FLUSH_DR = "'b".$DUMMY_HI_BITS."_".'0' x $FLUSH_bits; ### CAREFUL!!! I NEED TO ADD DUMMY_HI BITS TOO, IT IS TDI!
	
	return $FLUSH_DR;
};

sub RETURN_DUMMY_HI_REG{
	my ($REG_name, $tap) = @_;
	
	### I HAVE TO ADD HERE ALSO POSSIBLE PREPAD!!!
	my $DUMMY_HI_BITS; #I need to define it here to get the value out.
	my $register = $tap->get_register ($REG_name);
	## We could do just: $my $alias = register->get_alias ($alias_name); my $numbitsHI = $alias->get_size; my $DUMMY_HI_BITS = 0 x $numbitsHI; But only if sure about the dummy high name.
	my @list_register_aliases = SPF::Alias::sort($register->get_each_alias);
	my @list_register_aliases_names;
	foreach my $alias (@list_register_aliases){
		my $name = $alias->get_name;
    	if ($name =~ m/(dummy.*hi|DUMMY.*HI|dummy.*HI|DUMMY.*hi)/){ #We look for some of options for dummy high
			my $numbitsHI = $alias->get_size;
			$DUMMY_HI_BITS = 0 x $numbitsHI;
			last;
		}
	}
	return $DUMMY_HI_BITS;
}


###### FUNCTION NOT USED in case of using @set tap_skip_dr_back_padding on/off
sub TAP_LINK_DR{
	my ($parallel, $tap) = @_;
	
	#NEW:
	my $hastaplink = 0;
	my $tap_linkdr_encoding; #Defined here if I want it to be available out of the if.
	if ($tap->has_taplink){
		$hastaplink = 1;
		if ($parallel =~ "yes"){
			my ($tap_linkdr_opcode) =  grep { $_->is_global } $tap->get_each_taplink_dr_opcode;
			$tap_linkdr_encoding =  $tap_linkdr_opcode->get_encoding;
			$tap_linkdr_encoding    =~ s/^\'b//;
			my $parent_tap = $tap->get_parent;
			my $sizelink = $parent_tap->get_irsize;
			#my $sizelink = $tap_linkdr_opcode->get_size; #Doesn't work fine. It says size is 12, when it is 9 in reality.
			#print "sizeopcode: $sizelink\n";
			$tap_linkdr_encoding = sprintf( "%".$sizelink."d", $tap_linkdr_encoding );
		}else{
			my ($tap_linkdr_opcode) =  grep { $_->is_local } $tap->get_each_taplink_dr_opcode;
			$tap_linkdr_encoding =  $tap_linkdr_opcode->get_encoding;
			$tap_linkdr_encoding    =~ s/^\'b//;
                        my $parent_tap = $tap->get_parent;
                        my $sizelink = $parent_tap->get_irsize;
			#my $sizelink = $tap_linkdr_opcode->get_size;
			$tap_linkdr_encoding = sprintf( "%".$sizelink."d", $tap_linkdr_encoding );
		}
	}
	return ($hastaplink, $tap_linkdr_encoding); ### If $hastaplink is zero, means there is no TAP_LINK for such chain
}
1;

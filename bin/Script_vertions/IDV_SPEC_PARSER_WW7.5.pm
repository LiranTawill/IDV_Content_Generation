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
		chomp $line; #cut the /n in the end of the line if it exist 
					
		if ($line =~ m/(IDV.*|idv.*|PLL.*|pll.*)/){#IDV and PLL aer enabled by default
			my @Fub_Array = split / /, $line;
			my @fub_instance = $Fub_Array[0];	##### get the fub instance. From: "$MODEL_ROOT/cte/dft/global_chain/core_te/spec/client/core_global_system_spec.e"
			my @fub_type = $Fub_Array[1];			##### get the fub type
			#my @fub_pg = $line =~ /powergated\=(FALSE|TRUE)/;				##### get if power gated or not
			my $size=0;
			$fub_instance[0]=~ s/\s//g;$fub_type[0]=~ s/\s//g;				###### remove any possible white space
			$fub{$fub_instance[0]} = [ $fub_type[0],$size];			##### link them together for afterwards
			
			
			
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
	my @list_aliases = SPF::Alias::sort($IDV_Control_Register->get_each_alias);#all the bit names from spec
	my %list_CNTR_aliases_names = ();
	
	my @list_CTL_aliases_names;
	
	foreach my $alias (@list_aliases){
			my $name = $alias->get_name;
			$name =~ s/\..*//g ; #all we have before the . (delete all from . till end )
			my $numbits = $alias->get_size;
			$list_CNTR_aliases_names{$name} =  $numbits ;
			
			push (@list_CTL_aliases_names, $name);# to preserve the fublets order
	}
	
	### Order fublets properly:
	#my @BYPASS_DR;
	my @fublet_order; #what we will send
	foreach my $alias (@list_CTL_aliases_names){
		#$alias =~ s/\..*//g ;
		my $alias_name = $alias;
		$alias = $alias."_end";
		for my $fub_instance ( keys %fub ) {
			my $FUBINSTANCE = $fub_instance;
			$FUBINSTANCE = $FUBINSTANCE."_end";
			if ($FUBINSTANCE ne ""){
				if ($alias =~ $FUBINSTANCE){
					
					$fub{$fub_instance}[1]=$list_CNTR_aliases_names{$alias_name}; #Size of alias for adress size
					#### ADD HERE THE ORDERED FUB SEQUENCE!!!
					push (@fublet_order, $alias_name);#enter the fub name.
					last;#break the loop.
				}
			}
		}		
	}
	@fublet_order = reverse(@fublet_order); # reverse because of the push in the next Func
	#############################################################	
	return (\@fublet_order);
};

sub RETURN_DUMMY_HI_REG{
	my ($REG_name, $tap) = @_;
	
	### I HAVE TO ADD HERE ALSO POSSIBLE PREPAD!!!
	my $DUMMY_HI_BITS=''; #I need to define it here to get the value out.
	my $register = $tap->get_register ($REG_name);
	## We could do just: $my $alias = register->get_alias ($alias_name); my $numbitsHI = $alias->get_size; my $DUMMY_HI_BITS = 0 x $numbitsHI; But only if sure about the dummy high name.
	my @list_register_aliases = SPF::Alias::sort($register->get_each_alias);
	#my @list_register_aliases_names;
	foreach my $alias (@list_register_aliases){
		my $name = $alias->get_name;
    	if ($name =~ m/(dummy.*hi|DUMMY.*HI|dummy.*HI|DUMMY.*hi|dummy.*msb|DUMMY.*msb|DUMMY.*MSB|dummy.*MSB)/){ #We look for some of options for dummy high
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
			###For debug
			#@f=$tap->get_each_taplink_dr_opcode;
			#foreach my $a (@f){
			#	pass itpp "==> INFO: $a";
			#	my $b = grep { $_->is_local } $a;
			#	pass itpp "==> INFO: Local $b";
			#	my $c = $a->get_encoding;
			#	pass itpp "==> INFO: encoding $c";
			#	my $d = grep { $_->is_global } $a;
			#	pass itpp "==> INFO: Global $d";
			#}
			####
			#TAP_GLUE GLUE_CORE0_CORE {
			#OPCODES {
			#	CLTAP_CORE0_COREIR : 'h944 : %LINK_IR;
			#	CLTAP_CORE0_COREDR : 'h945 : %LINK_DR; This is for not parallel
			#	CLTAP_CORE0_CORECFG : 'h946 : %LINK_CFG;
			#	CLTAP_CORE0_CORESTATUS : 'h947 : %LINK_STATUS;
			#	CLTAP_CORE_CORE_TAPPARIR : 'hac4 : %LINK_PAR_IR;
			#	CLTAP_CORE_CORE_TAPPARDR : 'hac5 : %LINK_PAR_DR; This is for  parallel
			#	CLTAP_CORE_CORE_TAPPARCFG : 'hac6 : %LINK_PAR_CFG;
			#	CLTAP_CORE_CORE_TAPPARSTATUS : 'hac7 : %LINK_PAR_STATUS;
			#}
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

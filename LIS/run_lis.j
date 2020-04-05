#!/bin/csh

#SBATCH --job-name=irr
#SBATCH --ntasks=112
#SBATCH --constraint=hasw
#SBATCH --time=3:00:00
#SBATCH --account s1189
#SBATCH --workdir=WORKDIR
#SBATCH -o output.%j
#SBATCH -e error.%j
#SBATCH --mail-user=sarith.p.mahanama@nasa.gov
#SBATCH --mail-type=ALL

# Load the module used to compile LIS
# Set "Number of processors along x and y" in lis.config to match 
# number of ntasks and number of processors for mpirun 

source /home/smahanam/.cshrc
module use --append $HOME/privatemodules
module purge
module load lis_7_intel_18_0_3_222_cg
limit stacksize unlimited

mpirun -np 112 ./LIS -f LISCONFIGFILE

if (CONCAT == 1) then

#######################################################################
#               Concatenating Sub-daily Files to Daily Files
#######################################################################

    set SUBDIR = `ls -d OUTPUT/*/`
    set    PWD = `pwd`

    foreach DIR ($SUBDIR)
	set MONTHS = `ls $DIR`
	foreach MONTH ($MONTHS)
	    mkdir -p $DIR/$MONTH/save
	    set  YYYY = `echo $MONTH | cut -c1-4`
	    set    MM = `echo $MONTH | cut -c5-6`
	    set NDAYS = ` cal $MM $YYYY | awk 'NF {DAYS = $NF}; END {print DAYS}'`
	    set TIME_STEPS = `ls -1 $DIR/$MONTH/LIS_HIST* | rev | cut -d'_' -f1 | cut -d'.' -f3 | rev`
	    set LEN = `echo $#TIME_STEPS`
	    if ($LEN > 1) then
	    
		# sub-daily LIS_HIST files
		# create daily and remove the sub-daily
		# -------------------------------------
		set day=1
		while ($day <= $NDAYS)
		    if ( $day < 10  ) set DD=0${day}
		    if ( $day >= 10 ) set DD=${day}
		    set TIME_STEPS = `ls -1 $DIR/$MONTH/LIS_HIST_${YYYY}${MM}${DD}* | rev | cut -d'_' -f1 | cut -d'.' -f3 | rev`
		    set     TSTEP2 = \"`echo $TIME_STEPS | sed 's/\ /\","/g'`\"
		    set    LEN_SUB = `echo $#TIME_STEPS`
		    if($LEN_SUB > 1) then
			# change record dimension unlimited
			cd $DIR/$MONTH/
			set ALLFILES = `ls -1 LIS_HIST_${YYYY}${MM}${DD}*`
			foreach FILE ($ALLFILES)
			    ncks -6 --mk_rec_dmn time $FILE save/$FILE
			    /bin/mv save/$FILE .
			end
			cd $PWD
			
cat << EOF > timestamp.cdl
netcdf timestamp {
dimensions:
time = UNLIMITED ; // (NT currently)
string_length = 12 ;
variables:
char time_stamp (time, string_length) ;

data:

time_stamp =
DATAVALUES;
}      
EOF
   
			sed -i -e "s/NT/$LEN_SUB/g" timestamp.cdl
			sed -i -e "s/DATAVALUES/$TSTEP2/g" timestamp.cdl
			ncgen -k4 -o timestamp.nc4 timestamp.cdl
			ncrcat -h $DIR/$MONTH/LIS_HIST_${YYYY}${MM}${DD}*  $DIR/$MONTH/LIS_HIST_${YYYY}${MM}${DD}.nc4
			ncks -4 -h -v time_stamp timestamp.nc4 -A $DIR/$MONTH/LIS_HIST_${YYYY}${MM}${DD}.nc4
			/bin/rm timestamp.cdl
			/bin/rm timestamp.nc4
			/bin/mv $DIR/$MONTH/LIS_HIST_${YYYY}${MM}${DD}* $DIR/$MONTH/save/.
			/bin/mv $DIR/$MONTH/save/LIS_HIST_${YYYY}${MM}${DD}.nc4 $DIR/$MONTH/.	     
		    endif
		    @ day++ 
		end # concatenate for each day 	    
	    endif
	/bin/rm -r $DIR/$MONTH/save
	end
    end
endif

# The end
exit 0

#!/bin/csh -f

set      EXPID = gldas_flood
set START_DATE = 20150101
set LIS_CONFIG = lis7.config.noah33_gldas025_irr
set  FIRST_RST = /discover/nobackup/hkato/GLDAS/input025/LIS_RST_NOAH33_201501010000.d01.nc 
set  MODEL_RID = LIS_RST_NOAH33_
set    JOB_CNT = 12
set   NMON_JOB = 1
set        PWD = `pwd`
set  MODEL_RST = OUTPUT/SURFACEMODEL/
set     CONCAT = 1 

#######################################################################
#                     Create Links
#######################################################################


mkdir -p $EXPID/logs
cd $EXPID

/bin/ln -s /discover/nobackup/smahanam/LIS/EXECS/SM_irrig_tests1/LIS
/bin/ln -s /discover/nobackup/projects/lis/MET_FORCING/
/bin/ln -s /discover/nobackup/projects/lis/LS_PARAMETERS/
/bin/ln -s /gpfsm/dnb31/hkato/IRRIGATION/newtestcase/LIS/MODEL_OUTPUT_LIST.TBL
/bin/ln -s /gpfsm/dnb31/hkato/IRRIGATION/newtestcase/Noah33_InputFiles/
/bin/ln -s /gpfsm/dnb31/hkato/IRRIGATION/newtestcase/LIS/forcing_variables.txt
/bin/ln -s /gpfsm/dnb31/hkato/IRRIGATION/newtestcase/LDT/lis_input_noah33_gldas025_irr.nc

#######################################################################
#                    END USER MODIFICATIONS
#######################################################################

/bin/ln -s /discover/swdev/gmao_SIteam/Baselibs/latest-mpiuni/Linux/bin/ncks
/bin/ln -s /discover/swdev/gmao_SIteam/Baselibs/latest-mpiuni/Linux/bin/ncgen
/bin/ln -s /discover/swdev/gmao_SIteam/Baselibs/latest-mpiuni/Linux/bin/ncrcat
/bin/ln -s /discover/swdev/gmao_SIteam/Baselibs/latest-mpiuni/Linux/bin/ncra

cd $PWD

#######################################################################
#                          Submit jobs
#######################################################################

set job = 1

while ($job <= $JOB_CNT)

    set END_DATE = `date -d"$START_DATE +$NMON_JOB Month" +%Y%m%d`
    set Y1 = `echo $START_DATE | cut -c1-4`
    set M1 = `echo $START_DATE | cut -c5-6`    
    set Y2 = `echo $END_DATE | cut -c1-4`
    set M2 = `echo $END_DATE | cut -c5-6`

    /bin/cp -p $LIS_CONFIG $EXPID/LIS_CONFIG_$job
    sed -i -e "s/SYEAR/$Y1/g" $EXPID/LIS_CONFIG_$job
    sed -i -e "s/SMONTH/$M1/g" $EXPID/LIS_CONFIG_$job
    sed -i -e "s/EYEAR/$Y2/g" $EXPID/LIS_CONFIG_$job
    sed -i -e "s/EMONTH/$M2/g" $EXPID/LIS_CONFIG_$job
    if ($job == 1) then
	sed -i -e "s|RESTART_FILE|$FIRST_RST|g" $EXPID/LIS_CONFIG_$job
    else
	sed -i -e "s|RESTART_FILE|$MODEL_RST$Y1$M1/$MODEL_RID${Y1}${M1}010000.d01.nc|g" $EXPID/LIS_CONFIG_$job
    endif
    /bin/cp -p run_lis.j $EXPID/run_lis.$job.j
    sed -i -e "s|WORKDIR|$PWD\/$EXPID\/|g" $EXPID/run_lis.$job.j
    sed -i -e "s/LISCONFIGFILE/LIS_CONFIG_$job/g" $EXPID/run_lis.$job.j
    sed -i -e "s/CONCAT/$CONCAT/g" $EXPID/run_lis.$job.j
    set START_DATE = $END_DATE
    if ($job == 1) then
	set previous_jobid =  `sbatch $EXPID/run_lis.$job.j | cut -d' ' -f 4`
	echo $previous_jobid
    else
        set previous_jobid =  `sbatch --dependency=afterok:$previous_jobid $EXPID/run_lis.$job.j | cut -d' ' -f 4`
	echo $previous_jobid
    endif
    @ job++
end

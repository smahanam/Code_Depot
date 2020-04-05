#define VERIFY_(A)   IF(A/=0)THEN;PRINT *,'ERROR AT LINE ', __LINE__;STOP;ENDIF
#define ASSERT_(A)   if(.not.A)then;print *,'Error:',__FILE__,__LINE__;stop;endif

PROGRAM check_ESMF_funcs

  use ESMF
  implicit none
  include 'netcdf.inc'
  
  character(ESMF_MAXSTR)      :: str
  type(ESMF_VM)               :: VM
  type(ESMF_Calendar)         :: gregorianCalendar
  type(ESMF_Time)             :: CURRENT_TIME
  type(ESMF_Time),dimension (3) :: TBEG, TEND, TNEXT, PREVTIME,RINGTIME
  type(ESMF_Alarm)            :: TIME_ALARM
  type(ESMF_TimeInterval)     :: DELT, TIME_DIFF,T21, T20
  type(ESMF_Clock)            :: CLOCK  !The clock
  character*400               :: path, glfile, mlfile, gffile, mafile 
  integer                     :: status, rc,  NTIMES, n, ynext(3), ncgl, ncml, ncgg,ncma, NT_GL2, NT_GS, NT_MOD, NT
  character(len=4), dimension (:), target, allocatable :: MOD_MMDD, GL_MMDD, GS_MMDD
  character(len=4), dimension (:), pointer             :: MMDD
  character*10                :: string
  integer                     :: day,mm,dd, t1(3), t2(3)
  real(ESMF_KIND_R8)          :: tdiff_21, tdiff_20, tfrac(3)
  character(len=5), dimension (3) :: DNAME
  call ESMF_Initialize (vm=vm, logKindFlag=ESMF_LOGKIND_NONE, rc=status) ; VERIFY_(STATUS)
  call ESMF_CalendarSetDefault ( ESMF_CALKIND_GREGORIAN) 

  path   = '/discover/nobackup/rreichle/l_data/LandBCs_files_for_mkCatchParam/V001/'
  status = NF_OPEN(trim(path)//'GEOLAND2_10-DayClim/geoland2_lai_clim.H35V05.nc',NF_NOWRITE, ncgl) ; VERIFY_(STATUS)
  status = NF_OPEN(trim(path)//'MODIS_8-DayClim/MODIS_lai_clim.H15V17.nc'       ,NF_NOWRITE, ncml) ; VERIFY_(STATUS)
  status = NF_OPEN(trim(path)//'GSWP2_30sec_VegParam/GSWP2_VegParam_H34V07.nc'  ,NF_NOWRITE, ncgg) ; VERIFY_(STATUS)
  status = NF_OPEN(trim(path)//'MODIS-Albedo2/MCD43GF_wsa_H24V08.nc'            ,NF_NOWRITE, ncma) ; VERIFY_(STATUS)

  status = NF_INQ_DIM (ncgl,3,string ,NT_GL2) ; VERIFY_(STATUS)
  allocate (GL_MMDD (1:NT_GL2))
  status = NF_GET_VARA_text(ncgl, 3,(/1,1/),(/4,NT_GL2/),GL_MMDD(1:NT_GL2)); VERIFY_(STATUS)

  status = NF_INQ_DIM (ncml,3,string, NT_MOD) ; VERIFY_(STATUS)
  allocate (MOD_MMDD (1:NT_MOD))
  status = NF_GET_VARA_text(ncml, 3,(/1,1/),(/4,NT_MOD/),MOD_MMDD(1:NT_MOD)); VERIFY_(STATUS)

  status = NF_INQ_DIM (ncgg,3,string, NT_GS) ; VERIFY_(STATUS)
  allocate (GS_MMDD (1:NT_GS))
  status = NF_GET_VARA_text(ncgg, 3,(/1,1/),(/4,NT_GS/),GS_MMDD(1:NT_GS)); VERIFY_(STATUS)

  status = NF_CLOSE(ncgl); VERIFY_(STATUS)
  status = NF_CLOSE(ncml); VERIFY_(STATUS)
  status = NF_CLOSE(ncgg); VERIFY_(STATUS)
  status = NF_CLOSE(ncma); VERIFY_(STATUS)

  print *, size(GL_MMDD), ' ', (GL_MMDD(n), ' ', n = 1,  size(GL_MMDD))
  print *, size(MOD_MMDD), ' ', (MOD_MMDD(n), ' ', n = 1,  size(MOD_MMDD))
  print *, size(GS_MMDD), ' ', (GS_MMDD(n), ' ', n = 1,  size(GS_MMDD))

  call ESMF_TimeSet(CURRENT_TIME, yy=2002, mm=1, dd=1, rc=status) ; VERIFY_(STATUS)
  call ESMF_TimeIntervalSet(DELT, h=12, rc=status )            ; VERIFY_(STATUS) 

  DNAME (1) = 'MODIS'
  DNAME (2) = 'GSWP2'
  DNAME (3) = 'GEOLN'

! Initialize
! ----------

! Dimension (3) arrays: 
!            1) MODIS
!            2) GSWP2
!            3) GEOSLAND2 
! Data slices at 2 ends
  t1(1) = NT_MOD
  t1(2) = NT_GS
  t1(3) = NT_GL2 -1

  t2(1) = 1
  t2(2) = 1
  t2(3) = NT_GL2  

  DO N = 1,3

     IF(N == 1) MMDD => MOD_MMDD
     IF(N == 2) MMDD => GS_MMDD
     IF(N == 3) MMDD => GL_MMDD
     print *,n,'T1 : ', MMDD(t1(n))
     print *,n,'T2 : ', MMDD(t2(n))
     read(MMDD(t1(n)),'(i2.2,i2.2)') mm,dd
     call ESMF_TimeSet(TBEG(n), yy=2001, mm=mm, dd=dd, rc=status) ; VERIFY_(STATUS)
     read(MMDD(t2(n)),'(i2.2,i2.2)') mm,dd
     if(n <= 2) then        
        call ESMF_TimeSet(TEND(n), yy=2002, mm=mm, dd=dd, rc=status) ; VERIFY_(STATUS)
     else
        call ESMF_TimeSet(TEND(n), yy=2001, mm=mm, dd=dd, rc=status) ; VERIFY_(STATUS)
     endif
     
     TIME_DIFF  = TEND(n) - TBEG(n)
     PREVTIME(n) = TBEG(n) + TIME_DIFF / 2
     CALL ESMF_TimePrint ( PREVTIME(n), OPTIONS="string", RC=STATUS )

     if(n <= 2) then  
        t2(n) = t2(n)+1
        read(MMDD(t2(n)),'(i2.2,i2.2)') mm,dd
     else
        t2(n) = 1
        read(MMDD(1),'(i2.2,i2.2)') mm,dd
     endif
     call ESMF_TimeSet(TNEXT(n), yy=2002, mm=mm, dd=dd, rc=status) ; VERIFY_(STATUS)
     TIME_DIFF  = TNEXT(n) - TEND(n)
     RINGTIME(n)= TEND(n) + TIME_DIFF / 2
     CALL ESMF_TimePrint (RINGTIME(n), OPTIONS="string", RC=STATUS )

  ENDDO

  ynext(:) = 2002
  do day = 1,365*2
     CURRENT_TIME = CURRENT_TIME +DELT
     DO n= 1, 3
        T21 = RINGTIME(n) - PREVTIME(n) 
        T20 = RINGTIME(n) - CURRENT_TIME
        call ESMF_TimeIntervalGet(T21,s_r8=tdiff_21,rc=status) ; VERIFY_(STATUS) 
        call ESMF_TimeIntervalGet(T20,s_r8=tdiff_20,rc=status) ; VERIFY_(STATUS)
        tfrac(n) = tdiff_20/tdiff_21
     END DO
     print '(i3,3f8.5)',day/2, tfrac(:)
     DO n= 1, 3
        IF(CURRENT_TIME ==  RINGTIME(n)) THEN           
           PREVTIME(n) = RINGTIME(N)
           TEND(n)     = TNEXT (n)
           t1(n) = t2(n)
           t2(n) = t2(n) + 1           
           IF(N == 1) MMDD => MOD_MMDD
           IF(N == 2) MMDD => GS_MMDD
           IF(N == 3) MMDD => GL_MMDD
           IF(N == 1) NT = NT_MOD  
           IF(N == 2) NT = NT_GS 
           IF(N == 3) NT = NT_GL2
           if(t2(n) > NT) then
              t2(n) = 1
              ynext(n) =2003
           endif
           print *, DNAME(n), ' ',t1(n),':', t2(n)
           read(MMDD(t2(n)),'(i2.2,i2.2)') mm,dd
           call ESMF_TimeSet(TNEXT(n), yy=ynext(n), mm=mm, dd=dd, rc=status) ; VERIFY_(STATUS)
           TIME_DIFF  = TNEXT(n) - TEND(n)
           RINGTIME(n)= TEND(n) + TIME_DIFF / 2
!           CALL ESMF_TimePrint (CURRENT_TIME, OPTIONS="string", RC=STATUS )    
           CALL ESMF_TimePrint (RINGTIME(n), OPTIONS="string", RC=STATUS )           
        ENDIF
     END DO
  end do
  
END PROGRAM check_ESMF_funcs

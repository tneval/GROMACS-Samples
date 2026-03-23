#!/bin/bash

HOST_NAME=$(uname -n)

if [ "${HOST_NAME}" = "rtx01" ]; then

    GMX=/home/tapio/vault/repositories/gromacs-wts/PoCL-ACpp/build_acpp-8/install/bin/gmx
    GMX_MPI=/home/tapio/vault/repositories/gromacs-wts/PoCL-ACpp/acpp-mpi/install/bin/gmx_mpi
    ACPP_PATH=/filedump/tapio/repositories/AdaptiveCpp/build_rpathed/install/bin
    BM_DIR=/home/tapio/vault/repositories/GROMACS-Samples/OneDrive-2025-05-30/Benchmark_Inputs/Version_1
    #POCL_ICD_PATH=/home/tapio/vault/repositories/pocl-unpublished-wts/loopvec-next/build-20-Release/install/etc/OpenCL/vendors
    POCL_ICD_PATH=/home/tapio/vault/repositories/pocl-unpublished-wts/loopvec-next/build-LLVM22-R/install/etc/OpenCL/vendors

    N_STEPS=(5000 2500 1000 500 250 125 100 100 50 25 10 10 300)

elif [ "${HOST_NAME}" = "lupu" ]; then

    GMX=/home/tapio/repositories/GROMACS-wts/PoCL-ACpp/build_acpp/install/bin/gmx
    GMX_MPI=/home/tapio/repositories/GROMACS-wts/PoCL-ACpp/acpp_MPI/install/bin/gmx_mpi
    ACPP_PATH=/home/tapio/repositories/AdaptiveCpp-wts/disable-optimizations/build_20_sysLLVM/install/bin
    BM_DIR=/home/tapio/repositories/GROMACS-Samples/OneDrive-2025-05-30/Benchmark_Inputs/Version_1
    POCL_ICD_PATH=/home/tapio/repositories/pocl-unpublished-wts/loopvec-next/build-22/install/etc/OpenCL/vendors

    N_STEPS=(5000 2500 1000 500 250 125 100 100 50 25 10 10 300)

elif [ "${HOST_NAME}" = "neptune" ]; then

    GMX=/home/tapio/milkv-vault/repositories/gromacs-wts/PoCL-ACpp/build_acpp_simd_enable_v2/install/bin/gmx
    GMX_MPI=
    ACPP_PATH/home/tapio/milkv-vault/repositories/AdaptiveCpp-wts/disable-optimizations/build-llvm19/install/bin
    #BM_DIR=
    POCL_ICD_PATH=/home/tapio/milkv-vault/repositories/pocl-unpublished-wts/loopvec-next/build-19-RELEASE/install/etc/OpenCL/vendors

    N_STEPS=(512 256 128 64 32 16 8 4 2 2 2 2 30)
fi


export OCL_ICD_VENDORS=$POCL_ICD_PATH
export PATH=${ACPP_PATH}:$PATH

# These add some additional info to the logs.
#export GMX_CYCLE_ALL=1
#export GMX_DETAILED_PERF_STATS=1

if [ -z "$1" ]; then
    echo "No output log path provided"
    exit 1
fi


LOG_PATH=$1

mkdir -p ${LOG_PATH}

OUTPUT_PATH=$(pwd)/$LOG_PATH

echo "Saving logs to: $OUTPUT_PATH"

POCL_CACHE=$OUTPUT_PATH/pocl-cache

ACPP_CACHE=$OUTPUT_PATH/acpp-cache

# Log the software stack
SW_STACK_INFO=$OUTPUT_PATH/sw-stack-info.txt

touch $SW_STACK_INFO

clinfo >> $SW_STACK_INFO

acpp-info >> $SW_STACK_INFO

$GMX --version >> $SW_STACK_INFO

$GMX_MPI --version >> $SW_STACK_INFO

lscpu >> $SW_STACK_INFO

# Misc env variables needed:
export GMX_SYCL_ALLOW_ALL_DEVICES=1
export POCL_SUB_GROUP_SIZE=32
export POCL_CPU_MAX_CU_COUNT=1
export POCL_CACHE_DIR=$POCL_CACHE
export ACPP_APPDB_DIR=$ACPP_CACHE

# NOTE! PoCL rematerialization has to be disabled for now.
export POCL_PREGION_VALUE_REMAT=0

INPUTS=(grappa-0001.5 grappa-0003 grappa-0006 grappa-0012 grappa-0024 grappa-0048 grappa-0096 grappa-0192 grappa-0384 grappa-0768 grappa-1536 grappa-3072 rnase_cubic)
N_ITER=1

N_RANKS=4


cd ${BM_DIR}

#
for index in "${!INPUTS[@]}"; do
    for i in $(seq 1 "$N_ITER"); do

        # Set the number of cold run steps
        if (( ${N_STEPS[$index]} > 5 )); then
            COLD_STEPS=5
        else
            COLD_STEPS=2
        fi


        mkdir -p "${OUTPUT_PATH}/${INPUTS[$index]}"


        # RF, host-only, 1 rank:
        LOGFILE_RF_HOST="${OUTPUT_PATH}/${INPUTS[$index]}/RF-HOST-R1"

        if [ -f "${LOGFILE_RF_HOST}.log" ]; then
            echo "Skipping ${LOGFILE_RF_HOST} (log exists)"
        else

            # On RISC-V run autovectorized and nonvectorized cpu kernel
            if [ "${HOST_NAME}" = "neptune" ]; then

                # Autovectorization friendly kernel
                export GMX_NBNXN_PLAINC_1X1=1
                $GMX mdrun -s ${INPUTS[index]}-rf.tpr -ntmpi 1 -ntomp 1 -pin on -nb cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_HOST}-autovec -v
                unset GMX_NBNXN_PLAINC_1X1

                $GMX mdrun -s ${INPUTS[index]}-rf.tpr -ntmpi 1 -ntomp 1 -pin on -nb cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_HOST} -v
            else
                $GMX mdrun -s ${INPUTS[index]}-rf.tpr -ntmpi 1 -ntomp 1 -pin on -nb cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_HOST} -v
            fi


        fi


        # PME, host-only, 1 rank:
        LOGFILE_PME_HOST="${OUTPUT_PATH}/${INPUTS[$index]}/PME-HOST-R1"

        if [ -f "${LOGFILE_PME_HOST}.log" ]; then
            echo "Skipping ${LOGFILE_PME_HOST} (log exists)"
        else

            # On RISC-V run autovectorized and nonvectorized cpu kernel
            if [ "${HOST_NAME}" = "neptune" ]; then

                # Autovectorization friendly kernel
                export GMX_NBNXN_PLAINC_1X1=1
                $GMX mdrun -s ${INPUTS[$index]}-pme.tpr -ntmpi 1 -ntomp 1 -pin on -nb cpu -pme cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_HOST}-autovec -v
                unset GMX_NBNXN_PLAINC_1X1

            fi

            $GMX mdrun -s ${INPUTS[$index]}-pme.tpr -ntmpi 1 -ntomp 1 -pin on -nb cpu -pme cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_HOST} -v


        fi

        # RF, partially GPU-resident, 1 rank:
        LOGFILE_RF_PGPU="${OUTPUT_PATH}/${INPUTS[$index]}/RF-pGPU-R1"

        if [ -f "${LOGFILE_RF_PGPU}.log" ]; then
            echo "Skipping ${LOGFILE_RF_PGPU} (log exists)"
        else
            $GMX mdrun -s ${INPUTS[$index]}-rf.tpr -ntmpi 1 -ntomp 1 -pin on -nb gpu -bonded cpu -update cpu -nsteps ${COLD_STEPS} -nobackup -noconfout -resethway -g ${LOGFILE_RF_PGPU} -v
            $GMX mdrun -s ${INPUTS[$index]}-rf.tpr -ntmpi 1 -ntomp 1 -pin on -nb gpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_PGPU} -v
        fi


        # PME, partially GPU-resident, 1 rank:
        LOGFILE_PME_PGPU="${OUTPUT_PATH}/${INPUTS[$index]}/PME-pGPU-R1"

        if [ -f "${LOGFILE_PME_PGPU}.log" ]; then
            echo "Skipping ${LOGFILE_PME_PGPU} (log exists)"
        else
            $GMX mdrun -s ${INPUTS[$index]}-pme.tpr -ntmpi 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded cpu -update gpu -nsteps ${COLD_STEPS} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_PGPU} -v
            $GMX mdrun -s ${INPUTS[$index]}-pme.tpr -ntmpi 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded cpu -update gpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_PGPU} -v
        fi


        # RF, fully GPU-resident, 1 rank:
        LOGFILE_RF_FGPU="${OUTPUT_PATH}/${INPUTS[$index]}/RF-fGPU-R1"

        if [ -f "${LOGFILE_RF_FGPU}.log" ]; then
            echo "Skipping ${LOGFILE_RF_FGPU} (log exists)"
        else
            $GMX mdrun -s ${INPUTS[$index]}-rf.tpr  -ntmpi 1 -ntomp 1 -pin on -nb gpu -bonded gpu -update gpu -nsteps ${COLD_STEPS} -nobackup -noconfout -resethway -g ${LOGFILE_RF_FGPU} -v
            $GMX mdrun -s ${INPUTS[$index]}-rf.tpr  -ntmpi 1 -ntomp 1 -pin on -nb gpu -bonded gpu -update gpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_FGPU} -v
        fi


        # PME, fully GPU-resident, 1 rank:
        LOGFILE_PME_FGPU="${OUTPUT_PATH}/${INPUTS[$index]}/PME-fGPU-R1"

        if [ -f "${LOGFILE_PME_FGPU}.log" ]; then
            echo "Skipping ${LOGFILE_PME_FGPU} (log exists)"
        else
            $GMX mdrun -s ${INPUTS[$index]}-pme.tpr -ntmpi 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded gpu -update gpu -nsteps ${COLD_STEPS} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_FGPU} -v
            $GMX mdrun -s ${INPUTS[$index]}-pme.tpr -ntmpi 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded gpu -update gpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_FGPU} -v
        fi


        ## Multi-rank part starts here:


        # RF, host-only, 2+ ranks:
        LOGFILE_RF_HOST_MULTIRANK="${OUTPUT_PATH}/${INPUTS[$index]}/RF-HOST-R${N_RANKS}"

        if [ -f "${LOGFILE_RF_HOST_MULTIRANK}.log" ]; then
            echo "Skipping ${LOGFILE_RF_HOST_MULTIRANK} (log exists)"
        else

            # On RISC-V run autovectorized and nonvectorized cpu kernel
            if [ "${HOST_NAME}" = "neptune" ]; then

                # Autovectorization friendly kernel
                export GMX_NBNXN_PLAINC_1X1=1
                mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-rf.tpr -ntomp 1 -pin on -nb cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_HOST_MULTIRANK}-autovec -v
                unset GMX_NBNXN_PLAINC_1X1

            fi

            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-rf.tpr -ntomp 1 -pin on -nb cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_HOST_MULTIRANK} -v
        fi


        #PME, host-only, 2+ ranks:
        LOGFILE_PME_HOST_MULTIRANK="${OUTPUT_PATH}/${INPUTS[$index]}/PME-HOST-R${N_RANKS}"

        if [ -f "${LOGFILE_PME_HOST_MULTIRANK}.log" ]; then
            echo "Skipping ${LOGFILE_PME_HOST_MULTIRANK} (log exists)"
        else

            # On RISC-V run autovectorized and nonvectorized cpu kernel
            if [ "${HOST_NAME}" = "neptune" ]; then

                # Autovectorization friendly kernel
                export GMX_NBNXN_PLAINC_1X1=1
                mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-pme.tpr -npme 1 -ntomp 1 -pin on -nb cpu -pme cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_HOST_MULTIRANK} -autovec -v
                unset GMX_NBNXN_PLAINC_1X1
            fi

            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-pme.tpr -npme 1 -ntomp 1 -pin on -nb cpu -pme cpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_HOST_MULTIRANK} -v
        fi


        # RF, partially GPU-resident, 2+ ranks:
        LOGFILE_RF_PGPU_MULTIRANK="${OUTPUT_PATH}/${INPUTS[$index]}/RF-pGPU-R${N_RANKS}"

        if [ -f "${LOGFILE_RF_PGPU_MULTIRANK}.log" ]; then
            echo "Skipping ${LOGFILE_RF_PGPU_MULTIRANK} (log exists)"
        else
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-rf.tpr -ntomp 1 -pin on -nb gpu -bonded cpu -update cpu -nsteps ${COLD_STEPS} -nobackup -noconfout -resethway -g ${LOGFILE_RF_PGPU_MULTIRANK} -v
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-rf.tpr -ntomp 1 -pin on -nb gpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_PGPU_MULTIRANK} -v
        fi

        # PME, partially GPU-resident, 2+ ranks:
        LOGFILE_PME_PGPU_MULTIRANK="${OUTPUT_PATH}/${INPUTS[$index]}/PME-pGPU-R${N_RANKS}"

        if [ -f "${LOGFILE_PME_PGPU_MULTIRANK}.log" ]; then
            echo "Skipping ${LOGFILE_PME_PGPU_MULTIRANK} (log exists)"
        else
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-pme.tpr -npme 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded cpu -update cpu -nsteps ${COLD_STEPS} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_PGPU_MULTIRANK} -v
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-pme.tpr -npme 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded cpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_PGPU_MULTIRANK} -v
        fi

        # RF, fully GPU-resident, 2+ ranks:
        LOGFILE_RF_FGPU_MULTIRANK="${OUTPUT_PATH}/${INPUTS[$index]}/RF-fGPU-R${N_RANKS}"

        if [ -f "${LOGFILE_RF_FGPU_MULTIRANK}.log" ]; then
            echo "Skipping ${LOGFILE_RF_FGPU_MULTIRANK} (log exists)"
        else
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-rf.tpr -ntomp 1 -pin on -nb gpu -bonded gpu -update cpu -nsteps ${COLD_STEPS} -nobackup -noconfout -resethway -g ${LOGFILE_RF_FGPU_MULTIRANK} -v
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-rf.tpr -ntomp 1 -pin on -nb gpu -bonded gpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -resethway -g ${LOGFILE_RF_FGPU_MULTIRANK} -v
        fi

        # PME, fully GPU-resident, 2+ ranks:
        LOGFILE_PME_FGPU_MULTIRANK="${OUTPUT_PATH}/${INPUTS[$index]}/PME-fGPU-R${N_RANKS}"

        if [ -f "${LOGFILE_PME_FGPU_MULTIRANK}.log" ]; then
            echo "Skipping ${LOGFILE_PME_FGPU_MULTIRANK} (log exists)"
        else
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-pme.tpr -npme 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded gpu -update cpu -nsteps ${COLD_STEPS} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_FGPU_MULTIRANK} -v
            mpirun -np ${N_RANKS} ${GMX_MPI} mdrun -s ${INPUTS[$index]}-pme.tpr -npme 1 -ntomp 1 -pin on -nb gpu -pme gpu -bonded gpu -update cpu -nsteps ${N_STEPS[$index]} -nobackup -noconfout -notunepme -resethway -g ${LOGFILE_PME_FGPU_MULTIRANK} -v
        fi


    done
done

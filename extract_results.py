#!/usr/bin/python3
import sys
from pathlib import Path
import csv

if __name__ == "__main__":

    all_data = {}

    result_path = sys.argv[1]

    p = Path(result_path)

    labels = ("Neighbor search", "Launch PP GPU ops.", "Force", "PME GPU mesh", "PME wait for PP", "Wait Bonded GPU", "Wait GPU NB local", "Wait GPU state copy", "NB X/F buffer ops.", "Update", "Constraints", "Kinetic energy", "Rest ", "Wait PME GPU D2H", "PME 3D-FFT", "PME solve", "Wait PME GPU gather", "Reduce GPU PME F","Launch PME GPU ops.")

    for subdir in p.iterdir():
        if subdir.is_dir():

            # This is dict for single input
            input_data = {}

            # Name of the input
            input_name = str(subdir).split("/")[1]

            #print(input_name)


            for subsubdir in subdir.iterdir():

                test_data = {}

                with open(subsubdir) as res:
                    for line in res:
                        if line.strip().startswith("gmx mdrun"):
                            #print(line.split())
                            idx = line.split().index("-nsteps")
                            test_data["n_steps"] = line.strip().split()[idx+1]


                        for label in labels:
                            if line.lstrip().startswith(label):
                                current_label = label.replace(" ", "_")
                                wall_time = line.strip().split()[-3]
                                #input_data.append({ "name": current_label, "unit": "Seconds", "value": float(wall_time)})
                                test_data[current_label] = float(wall_time)

                        # Also extract the total core and wall time
                        if line.lstrip().startswith("Time:"):
                            split_total_time = line.lstrip().split()
                            test_data["Total_core_time"] = float(split_total_time[1])
                            test_data["Total_wall_time"] = float(split_total_time[2])
                            #input_data.append({ "name": "Total_core_time", "unit": "Seconds", "value": float(split_total_time[1])})
                            #input_data.append({ "name": "Total_wall_time", "unit": "Seconds", "value": float(split_total_time[2])})

                #print(test_data)

                log_file = str(subsubdir).split("/")[2].split(".")[0]

                input_data[log_file] = test_data


                #print(subsubdir)
            #print(input_data)
            #print(subdir)

            all_data[input_name] = input_data


    print(all_data)

    with open("data.csv", "w") as csv_out:
        #labels = ("Neighbor search", "Launch PP GPU ops.", "Force", "PME GPU mesh", "PME wait for PP", "Wait Bonded GPU", "Wait GPU NB local", "Wait GPU state copy", "NB X/F buffer ops.", "Update", "Constraints", "Kinetic energy", "Rest ", "Wait PME GPU D2H", "PME 3D-FFT", "PME solve", "Wait PME GPU gather", "Reduce GPU PME F","Launch PME GPU ops.")

        titles = ["input", "run", "n_steps", "Neighbor_search", "Launch_PP_GPU_ops.", "Force", "PME_GPU_mesh", "PME_wait_for_PP", "Wait_Bonded_GPU", "Wait_GPU_NB_local", "Wait_GPU_state_copy", "NB_X/F_buffer_ops.", "Update", "Constraints", "Kinetic_energy", "Rest", "Wait_PME_GPU_D2H", "PME_3D-FFT", "PME_solve", "Wait_PME_GPU_gather", "Reduce_GPU_PME_F","Launch_PME_GPU_ops.", "Total_core_time", "Total_wall_time"]
        writer = csv.writer(csv_out)
        writer.writerow(titles)
        for input, run in sorted(all_data.items()):

            #writer.writerow([input])
            for log, datas in run.items():
                new_row = []
                new_row.append(input)
                new_row.append(log)

                for title in titles:
                    if (title != "input") & (title != "run"):
                        if title in datas.keys():
                            new_row.append(datas[title])
                        else:
                            new_row.append("")

                writer.writerow(new_row)
                #writer.writerow(datas.values())

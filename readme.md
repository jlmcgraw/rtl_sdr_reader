# Setting up an NooElec R820T SDR to monitor power and temperature readings in Linux


# Software and Hardware requirements

    - A Debian based Linux system
    - A NooElec R820T USB DVB-T TV Tuner
    - Ambient Weather F0007TH Thermo-Hygrometer for temperature/humidity readings

# After inserting the USB stick, you may need to stop previously loaded kernel modules first

    sudo rmmod rtl2832_sdr dvb_usb_rtl28xxu rtl2832

    Or to permanently blacklist the default module
    edit /etc/modprobe.d/blacklist and add:
        blacklist dvb_usb_rtl28xxu
        blacklist rtl2832
        blacklist rtl2830 
        blacklist rtl2832_sdr

# Compile and install rtlamr ( reads various devices which report data on 900mhz )
    
    sudo apt update && sudo apt upgrade
    sudo apt install rtl-sdr golang git
    go get github.com/bemasher/rtlamr

    open two separate terminals do an initial test:
        1) rtl_tcp
        2)  ~/go/bin/rtlamr -msgtype=scm -unique=true
                (test out the various message types to see what you're picking up locally)

    You'll have to figure out what the IDs of your various meters are.
    The easiest way is probably to go look at the boxes and find the ID number on them

    Stop rtl_tcp when you're done testing here

# Compile rtl_433 ( reads various devices which report data on 433mhz )

        sudo apt-get install    \
            build-essential     \
            cmake               \
            librtlsdr-dev

        git clone https://github.com/merbanan/rtl_433.git
        cd rtl_433/

        # Before building, let's make some simple edits so that
        # we can use it with rtl_tcp and output local times as ISO 8601
        # These are "git diff" output and will probably not work perfectly but will 
        # give you an idea where to make the edits


            # Patch rtl_433.c to honor timer settings when reading from a file
                diff --git a/src/rtl_433.c b/src/rtl_433.c
                index 1156337..71690d8 100644
                --- a/src/rtl_433.c
                +++ b/src/rtl_433.c
                @@ -1165,6 +1165,9 @@ int main(int argc, char **argv) {
                                 duration = atoi_time(optarg, "-T: ");
                                 if (duration < 1) {
                                     fprintf(stderr, "Duration '%s' not a positive number; will continue indefinitely\n", optarg);
                +                } else {
                +                    time(&stop_time);
                +                    stop_time += duration;
                                 }
                                 break;
                             case 'y':
                @@ -1389,7 +1392,7 @@ int main(int argc, char **argv) {
                             rtlsdr_callback(test_mode_buf, n_read, demod);
                             i++;
                             sample_file_pos = (float)i * n_read / samp_rate / 2;
                -        } while (n_read != 0);
                +        } while (n_read != 0 && !do_exit);
                 
                         // Call a last time with cleared samples to ensure EOP detection
                         memset(test_mode_buf, 128, DEFAULT_BUF_LENGTH);  // 128 is 0 in unsigned data


            # Patch util.c to make it report sample times properly when reading from a file
            # and make it report local times formatted per ISO 8601
                diff --git a/src/util.c b/src/util.c
                index c7c107d..3301dae 100644
                --- a/src/util.c
                +++ b/src/util.c
                @@ -139,10 +139,12 @@ char* local_time_str(time_t time_secs, char *buf)
                 
                     if (time_secs == 0) {
                         extern float sample_file_pos;
                -        if (sample_file_pos != -1.0) {
                -            snprintf(buf, LOCAL_TIME_BUFLEN, "@%fs", sample_file_pos);
                -            return buf;
                -        }
                +        // Commented out to allow time to be reported correctly when reading
                +        // from a file
                +        //if (sample_file_pos != -1.0) {
                +        //    snprintf(buf, LOCAL_TIME_BUFLEN, "@%fs", sample_file_pos);
                +        //    return buf;
                +        //}
                         time(&etime);
                     } else {
                         etime = time_secs;
                @@ -150,7 +152,8 @@ char* local_time_str(time_t time_secs, char *buf)
                 
                     tm_info = localtime(&etime); // note: win32 doesn't have localtime_r()
                 
                -    strftime(buf, LOCAL_TIME_BUFLEN, "%Y-%m-%d %H:%M:%S", tm_info);
                +    // Output local times as ISO 8601
                +    strftime(buf, LOCAL_TIME_BUFLEN, "%FT%T%z", tm_info);
                     return buf;
                 }

        mkdir build
        cd build
        cmake ../
            or ( cmake -DCMAKE_BUILD_TYPE=Debug ../  )
        make
        # executable will be "src/rtl_433"
        # make install
        
        Now test out rtl_433.  You'll need to make sure rtl_tcp is no longer running

            ./src/rtl_433

# Alternately capture both types of data using rtl_tcp
    ./both_readers.sh

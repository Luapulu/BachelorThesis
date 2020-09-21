getA(signal) = maximum(diff(signal))

total_drift_time(signal, step_time_out=SETUP.step_time_out) = argmax(signal) * step_time_out

# sytolic_array (Based on ready-valid handshake)

- M x M systolic array simulation 

**systolic array + FIFO (no skid buffer, M=3 version simulation)**

![image](https://github.com/seo459/sytolic_array/assets/72679290/ba07bdc1-6459-42b0-b8cc-bb907bde248e)

![image](https://github.com/seo459/sytolic_array/assets/72679290/c5cb97bf-a6c2-43a3-8b92-74d8dc3a830f)

105ns : PE[0][0], first input

115ns : PE[0][1], PE[1][0], first input

125ns : PE[0][2], PE[2][0], first input

...

165ns : DONE (7 cycles after the start signal) (For M=3 and without skid buffer)

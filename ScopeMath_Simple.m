function ScopeMath_Simple(useSimulatedData)

if ~exist('useSimulatedData','var')
   useSimulatedData = 1;
end

% GUI variables
hFigure = [];
hAxesRaw = [];
hAxesMath = [];
hStartButton = [];
acquiringData = false;

% Instrument control variables
interfaceObj = []; 
deviceObj = [];    
channelObj = [];   
waveformObj = [];

% set up a timer to periodically get the data 
% from the instrument
timerObj = timer('Period', 1.5, 'ExecutionMode', 'fixedSpacing', ...
                  'timerFcn', @getDataFromInstrument);
               
makeGUI(); 

if useSimulatedData 
   msgbox('Using simulated data');
else
   connectToInstrument();
end

              
  %%---------------------------------------------------   
   function connectToInstrument
      try
         % THE FOLLOWING TWO LINES SHOULD BE CHANGED TO SUIT YOUR HARDWARE
         interfaceObj = visa('tek', 'USB0::1689::871::C010151::0::INSTR:');
         deviceObj = icdevice('tektronix_tds2012', interfaceObj);
         connect(deviceObj);
         channelObj = deviceObj.Channel(1); % read from channel 1
         waveformObj = deviceObj.Waveform(1);  % default waveform measurement
      catch         
         cleanupObjects();
         rethrow(lasterror);
      end
   end

  %%---------------------------------------------------
   function getDataFromInstrument(hObject, eventdata)
      if useSimulatedData
         % 30 Hz sinusoid with additive Gaussian noise
         xData = linspace(0,1,256); 
         yData = sin(30*2*pi*xData) + randn(size(xData))*0.2; 
         xUnits = 'seconds'; yUnits = 'Volts';
      else
         if ~(strcmp(deviceObj.Status, 'open')  && strcmp(channelObj.State, 'on'))
            cleanupObjects();
            error('Not connected to device, or channel is disabled on the scope.');
         end
         [yData, xData, yUnits, xUnits] = ...
            invoke(waveformObj, 'readwaveform', channelObj.name);
      end

     % check the user closed the window while we were waiting
     % for the instrument to return the waveform data
     if ishandle(hFigure),       
        axes(hAxesRaw);
        plot(xData,yData);
        xlabel(xUnits); ylabel(yUnits);
        %
        axes(hAxesMath);
        [freq,fftdata] = powerSpectrum(xData, yData);
        plot(freq, fftdata);
        xlabel('Frequency (Hz)'); ylabel('Amplitude');
     end
   end

  %%---------------------------------------------------         
   function [freq,fftdata] = powerSpectrum(x,y)
      n = length(x);
      Fs = 1/(x(2)-x(1));
      freq = ((0:n-1)./n)*Fs;
      fftdata = 20*log10(abs(fft(y)));
      idx = 1:floor(length(freq)/2);
      freq = freq(idx);
      fftdata = fftdata(idx);
   end

  %%---------------------------------------------------   
   function makeGUI
      hFigure = figure('deleteFcn', @figureCloseCallback);
      hAxesRaw  = axes('position', [0.13  0.51  0.775 0.31]);
      title('Raw Data');
      hAxesMath = axes('position', [0.13  0.08  0.775 0.31]);      
      title('Processed Data');
      hStartButton = uicontrol('Style', 'PushButton', ...
                               'String', 'Start Acquisition', ...
                               'units', 'normalized', ...
                               'callback', @startStopCallback, ...
                               'position', [0.70 0.84 0.18 0.06]);
      set(hStartButton, 'callback', @startStopCallback);
   end

  %%---------------------------------------------------   
   function startStopCallback(hObject, eventdata)
      if acquiringData
         if strcmp(timerObj.running, 'on')
            stop(timerObj);
         end
         acquiringData = false;
         set(hObject, 'string', 'Start Acquisition');
      else     
         acquiringData = true;
         set(hObject, 'string', 'Stop Acquisition');
         if strcmp(timerObj.running, 'off')
             start(timerObj);
         end
      end         
   end

  %%---------------------------------------------------   
   function figureCloseCallback(hObject, eventdata)
      cleanupObjects();
   end

  %%---------------------------------------------------   
   function cleanupObjects()

      if isvalid(timerObj) 
         stop(timerObj); 
         delete(timerObj);
      end
      
      try
         if ~isnumeric(deviceObj) && isvalid(deviceObj)
            disconnect(deviceObj);
            delete(deviceObj);
         end
      catch
         delete(deviceObj); 
      end

      if ~isnumeric(deviceObj) && isvalid(interfaceObj)
         fclose(interfaceObj);
         delete(interfaceObj);
      end

      if ishandle(hFigure), 
         delete(hFigure); 
      end
   end

end % of ScopeMath_Simple


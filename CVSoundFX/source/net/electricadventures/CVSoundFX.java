package net.electricadventures;

//~ import javax.swing.SwingUtilities;
//~ import javax.swing.JFrame;
//~ import javax.swing.JPanel;
//~ import javax.swing.JButton;
//~ import javax.swing.BorderFactory;
//~ import java.awt.Color;
//~ import java.awt.Dimension;
//~ import java.awt.Graphics;
//~ import java.awt.event.ActionEvent;
//~ import java.awt.event.ActionListener;
//~ import java.awt.event.MouseEvent;
//~ import java.awt.event.MouseListener;
//~ import java.awt.event.MouseAdapter;
//~ import java.awt.event.MouseMotionListener;
//~ import java.awt.event.MouseMotionAdapter;

// Applet
import java.applet.*;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
// PSG_Emu
import java.net.*;
import java.io.*;
import java.util.*;

import javax.sound.sampled.*;

import javax.swing.filechooser.FileNameExtensionFilter;

class AudioDatum {
	// Default (dummy) values
	public int period = 0x44;
	public int attenuation = 3;
	
	public int p(int mode)
	{
		if (mode > 0) return period*2;
		return period;
	}
	
	public void autotune(int mode) {
		int n;
		switch (mode)
		{
			case 0:
				// TONE
				n = (int) (12.0f * Math.log(6839.92781623f / ((double) period)) / Math.log(2.0f));
				period = (int) (6839.92781623f / (Math.pow(2f,(double) n / 12.0f)));
				break;
			case 1:
				// PERIODIC NOISE
				n = (int) (12.0f * Math.log(455.99518774862249f / ((double) period)) / Math.log(2.0f));
				period = (int) (455.99518774862249f / (Math.pow(2f,(double) n / 12.0f)));
				break;
		}
	}
}

class AudioData {
	public int mode = 0;
	public int size;
	public int startAt;
	public int endAt;
	public AudioDatum[] sequence;
	
	public AudioData()
	{
		size = 120;
		sequence = new AudioDatum[size];
		reset();
	}
	
	public void reset()
	{
		//mode = 0;
		startAt = 0;
		endAt = size-1;
		for (int i=0; i<sequence.length; i++) {
			sequence[i] = new AudioDatum();
		}
	}
}

class AudioChip implements Runnable {
	
	public AudioData data;
	//public int mode; 
	private float amplitude[] = new float[16];
	private final int NTSC_FRAME = 3732;  /* (int) 3732.4254 */
	private int ShiftRegister;
	private int ShiftRegister_PRESET = 0x4000;
	
	// SPEAKER
	private byte current_state;
	private final byte S_NOTSET = 0x00;
	private final byte S_READY = 0x01;
	private final byte S_LOADING = 0x02;
	private final byte S_PLAYING = 0x04;
	private final byte S_STOPING = 0x08;
	private final byte S_STOPED = 0x10;
	private final byte S_CLOSING = 0x20;
	private final byte S_CLOSED = 0x40;

	static private int MAX_WAVE_AMPLITUDE = 127;
	private byte[] waveSample = new byte[88398];
	private int waveSampleSize;
	private int waveSamplePointer;

	private AudioFormat af_sample = new AudioFormat(44100f,8,1,true,false);
	private DataLine.Info dl_info;
	private SourceDataLine sdl_line;
	
	public AudioChip() {
		initialize_amplitude_table();
		current_state = S_NOTSET;
		// SPEAKER
		open_dataline();
	}
	
	private void reset() {
		ShiftRegister = ShiftRegister_PRESET;
	}

	public void setAudio(AudioData d) {
		this.data = d;
	}
	
	public void generateSound() {
		reset();
		
		// Generate sound data
		// ===================
		
		int index;
		int length = 0;
		int counter = 0;
		int count;
		AudioDatum d;
		boolean flipflop = true;
		int feedback;
		
		float ticksCounter = 0f;
		float ticksRate = 3579545.45f / 16f / 44100f;
		float accumulator = 0f;
		float accumulatorCounter = 0f;
		int accumulatorCount = 0;
		
		reset();
		
		waveSampleSize = 0;
		
		for (index = data.startAt; index<= data.endAt; index++)
		{
			d = data.sequence[index];
			if (d.attenuation == 15) {
				counter = 0;
				flipflop = true;
			}
			for (count =0; count < NTSC_FRAME; count++)
			{
				accumulatorCounter += 1f;
				accumulatorCount ++;
				accumulator += flipflop ? amplitude[d.attenuation] : 0f;
				if (accumulatorCounter >= ticksRate)
				{
					//System.out.println("Size = "+waveSampleSize+" , index = "+index);
					waveSample[waveSampleSize++] = (byte) (accumulator * MAX_WAVE_AMPLITUDE / accumulatorCount);
					accumulatorCounter -= ticksRate;
					accumulator = 0f;
					accumulatorCount = 0;
				}
				counter++;
				if (d.p(data.mode) > 0)
				{
					if (counter>=d.p(data.mode))
					{
						counter%=d.p(data.mode);
						switch (data.mode)
						{
							// TONE
							case 0:
								flipflop = !flipflop;
								break;
							// PERIODIC NOISE
							case 1:
								feedback = ShiftRegister & 1;
								ShiftRegister = (ShiftRegister >>> 1) | (feedback << 14);
								flipflop = ((ShiftRegister & 1) == 1);
								break;
							// WHITE NOISE
							case 2:
								feedback = (ShiftRegister ^ (ShiftRegister >>> 1)) & 1; 
								ShiftRegister = (ShiftRegister >>> 1) | (feedback << 14);
								flipflop = ((ShiftRegister & 1) == 1);
								break;
						}
					}
				}
			}
			if (accumulatorCounter > 0)
			{
				waveSample[waveSampleSize++] = (byte) (accumulator * MAX_WAVE_AMPLITUDE / accumulatorCount);
				//~ accumulatorCounter -= ticksRate;
				//~ accumulator = 0f;
				//~ accumulatorCount = 0;
			}
		}
		//~ for (int i=0; i<waveSampleSize; i++)
		//~ {
			//~ System.out.println("Datum : "+waveSample[i]);
		//~ }
	}
	
	private void open_dataline()
	{
		//System.out.println("OPEN_DATALINE");
		//af_sample = new AudioFormat(44100f,8,1,true,false);
		try
		{
			dl_info = new DataLine.Info(SourceDataLine.class,af_sample);
			if ( !AudioSystem.isLineSupported( dl_info ) )
			{
				current_state = S_NOTSET;
				return;
			}
			sdl_line = (SourceDataLine) AudioSystem.getLine( dl_info );
			/* the af_sample param is needed here
			* to support well the different versions of Java
			* from 1.4 to 1.5
			*/
			sdl_line.open(af_sample); 
			current_state = S_READY;
		}
		catch (Exception e)
		{
		    // do Nothing
		}
		//System.out.println("OPEN_DATALINE DONE");
	}
	
	public void stop_playing()
	{
		//System.out.println("STOP_PLAYING");
		if ( current_state == S_NOTSET) return;
		current_state = S_STOPING;
		while(current_state == S_STOPING);
		System.gc();
		//System.out.println("STOP_PLAYING DONE");
	}

	public void start_playing()
	{
		//System.out.println("START_PLAYING");
		if ( current_state == S_NOTSET) return;
		if ( current_state == S_PLAYING)
		{
			stop_playing();
		}
		generateSound();
		current_state = S_PLAYING;
		waveSamplePointer = 0;
		sdl_line.start();
		//System.out.println("START_PLAYING DONE");
	}

	public void close_dataline()
	{
		//System.out.println("CLOSE_DATALINE");
		try
		{
			sdl_line.stop();
			sdl_line.close();
		}
		catch (Exception e)
		{
			// do Nothing
		}
		current_state = S_CLOSED;
		//System.out.println("CLOSE_DATALINE DONE");
	}
    
	public void kill()
	{
		if ( current_state == S_NOTSET) return;
		if ( current_state == S_PLAYING)
		{
			stop_playing();
		}
		current_state = S_CLOSING;
	}
	
	public void run()
	{
		int data_left, block_size;
		while(current_state != S_CLOSING)
		{
			try
			{
				// Sleep for a while
				Thread.currentThread().sleep(50);
			}
			catch(InterruptedException e)
			{
				// Do nothing
			}
			
			while(current_state == S_PLAYING)
			{
				//System.out.println("S_PLAYING");
				data_left = waveSampleSize - waveSamplePointer;
				block_size = sdl_line.available();
				if (data_left < block_size) block_size = data_left;
				try
				{
					sdl_line.write(waveSample,waveSamplePointer,block_size);
					try
					{
						// Sleep for a while
						Thread.currentThread().sleep(2);
					}
					catch(InterruptedException e)
					{
					// Do nothing
					}
					waveSamplePointer += block_size;
					if (waveSampleSize == waveSamplePointer)
					{
						sdl_line.drain();
						current_state = S_STOPING;
					}
				}
				catch (Exception e)
				{
					// Do Nothing
				}
			}
			if (current_state == S_STOPING)
			{
				//System.out.println("S_STOPING");
				try
				{
					sdl_line.flush();
					sdl_line.stop();
				}
				catch (Exception e)
				{
					// Do Nothing
				}
				current_state = S_READY;
			}
		}
		close_dataline();
	}

	private void initialize_amplitude_table()
	{
		int i;
		amplitude[0] = 1.0f;
		for (i=1;i<15;i++) {
			amplitude[i] = amplitude[i-1] / 1.259f; // 1.258925412f;
		}
		amplitude[15] = 0.0f;
	}
}

class AudioPanel extends JPanel {
	
	public AudioData data;
	public int mode = 0;
	public boolean autotune = false;
	
	public AudioPanel(AudioData d)
	{
		setBorder(BorderFactory.createLineBorder(Color.black));	
		//setBackground(new Color(127,191,255));
		setBackground(Color.black);
		setForeground(Color.white);
		mouse();
		setAudioData(d);
	}
	
	public void setAudioData(AudioData d) {
		data = d;
	}
	
	public void mouse() {
        addMouseListener(new MouseAdapter() {
            public void mousePressed(MouseEvent e) {
				// Do something if mouse button is pressed
				clicked(e.getX(),e.getY());
            }
        });
        addMouseMotionListener(new MouseAdapter() {
            public void mouseDragged(MouseEvent e) {
				// Do something if mouse is dragged
				clicked(e.getX(),e.getY());
            }
        });
	}
	
	public void clicked(int x, int y) {
		//System.out.println("X="+x+" , Y="+y);
		if (x>=0 && x<=839) {
			if (y>=0 && y<=511)
			{
				int i = x/7;
				switch (mode)
				{
					case 0:
						data.sequence[i].period = y*2+1;
						if (autotune) {data.sequence[i].autotune(data.mode);}
						break;
					case 1:
						data.sequence[i].attenuation = y/32;
						break;
					case 2:
						data.startAt = i;
						if (data.startAt>data.endAt)  data.endAt = data.startAt;
						break;
					case 3:
						data.endAt = i;
						if (data.endAt<data.startAt)  data.startAt = data.endAt;
						break;
				}
			}
		}
		repaint();
	}
	
	public Dimension getPreferredSize() {
		return new Dimension(840,512);
	}

	public void paintComponent(Graphics g) {
		super.paintComponent(g);       
		// Draw Text
		g.drawString("Audio Sample",10,20);
		if (data != null) {
			AudioDatum[] seq = data.sequence;
			if (seq != null) {
				AudioDatum datum;
				for (int i=0; i<120; i++)
				{
					datum = seq[i];
					if (datum != null) {
						int y = datum.period/2;
						int y2 = datum.attenuation*32+ 15;
						if (i>=data.startAt && i<=data.endAt) {
							g.setColor(new Color(16 * (15-datum.attenuation),8*datum.attenuation,16*datum.attenuation));
							g.fillRect(i*7,y,7,512-y);
							g.setColor(Color.white);
							g.drawRect(i*7+1,y2,5,3);
						} else {
							g.setColor(Color.darkGray);
							g.fillRect(i*7,y,7,512-y);
							g.setColor(Color.gray);
							g.drawRect(i*7+1,y2,5,3);
						}
					}
					else {
						//System.out.println("NULL DATUM");
					}
				}
			} else {
				//System.out.println("NULL SEQUENCE");
			}
		}
		else {
			//System.out.println("NULL DATA");
		}
	}	
}

class PlayButton extends JButton {
	
	public AudioData data;
	public AudioChip chip;
	
	public PlayButton(AudioData d, AudioChip chip) {
		super("Play");
		mouse();
		setAudioData(d);
		setAudioChip(chip);
	}
	
	public void setAudioData(AudioData d) {
		data = d;
	}

	public void setAudioChip(AudioChip chip) {
		this.chip = chip;
	}
	
	public void mouse() {
		addActionListener(new ActionListener() {
		public void actionPerformed(ActionEvent e) {
			chip.setAudio(data); 
			chip.start_playing();
			//System.out.println("BUTTON PLAY CLICKED");
			}          
		});
	}
}

class ResetButton extends JButton {
	
	public AudioData data;
	public AudioPanel panel;
	
	public ResetButton(AudioData d, AudioPanel p) {
		super("Clear");
		mouse();
		panel = p;
		setAudioData(d);
	}
	
	public void setAudioData(AudioData d) {
		data = d;
	}

	public void mouse() {
		addActionListener(new ActionListener() {
		public void actionPerformed(ActionEvent e) {
			data.reset();
			panel.repaint();
			}          
		});
	}
}

class SaveButton extends JButton {
	
	public AudioData data;
	
	public SaveButton(AudioData d) {
		super("Save");
		mouse();
		setAudioData(d);
	}
	
	public void setAudioData(AudioData d) {
		data = d;
	}

	public void mouse() {
		addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				JFileChooser chooser = new JFileChooser();
				chooser.setDialogTitle("Save Sound Effect");
				chooser.setFileSelectionMode(JFileChooser.FILES_ONLY);
				chooser.setFileFilter(new FileNameExtensionFilter("Sound Effects (.sfx)", "sfx"));
				if(chooser.showSaveDialog(null) == JFileChooser.APPROVE_OPTION) {
					File file = chooser.getSelectedFile();
					String filePath = file.getPath();
					if(!filePath.toLowerCase().endsWith(".sfx"))
					{
					    file = new File(filePath + ".sfx");
					}
					if(file.exists())
					{
						int actionDialog = JOptionPane.showConfirmDialog(chooser,"The file exists, overwrite?","Existing file",JOptionPane.YES_NO_CANCEL_OPTION);
						//JOptionPane.showConfirmDialog(this,"Replace existing file?","Existing file",JOptionPane.YES_NO_CANCEL_OPTION);
						// may need to check for cancel option as well
						if (actionDialog == JOptionPane.NO_OPTION || actionDialog == JOptionPane.CANCEL_OPTION) return;
					}
					try
					{
						//PrintWriter writer = new PrintWriter(file.getPath(), "UTF-8");
						BufferedWriter o = new BufferedWriter(new FileWriter(file));
						o.write("MODE "+data.mode);
						o.newLine();
						o.write("SIZE "+data.size);
						o.newLine();
						o.write("START "+data.startAt);
						o.newLine();
						o.write("END "+data.endAt);
						o.newLine();
						for (int i=data.startAt; i<=data.endAt; i++)
						{
							AudioDatum datum = data.sequence[i];
							o.write(""+datum.period+" "+datum.attenuation);
							o.newLine();
						}
						o.flush();
						o.close();
					} catch (FileNotFoundException err) {
						err.printStackTrace();
					} catch (IOException err) {
						err.printStackTrace();
					}
				}
			}          
		});
	}
}

class ExportButton extends JButton {
	
	private final Object[] optionsTONECHANNEL = {
		"Tone Channel 1",
		"Tone Channel 2",
		"Tone Channel 3"};

	private final Object[] optionsSOUNDFORMAT = {
		"COLECO BIOS",
		"*sound format 2*"};

	private final Object[] optionsPROGRAMFORMAT = {
		"Assembly code (SDCC)",
		"*programming format 2*"};

	public AudioData data;
		
	public ExportButton(AudioData d) {
		super("Export");
		mouse();
		setAudioData(d);
	}
	
	public void setAudioData(AudioData d) {
		data = d;
	}

	public void mouse() {
		addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				int n;
				int TONECHANNEL = 3; // Default ch#3? */
				int SOUNDFORMAT;
				int PROGRAMFORMAT;
				
				if (data.mode == 0) {
					n = JOptionPane.showOptionDialog(null,
						"Which tone channel to use?",
						"Tone channel selection",
						JOptionPane.YES_NO_CANCEL_OPTION,
						JOptionPane.QUESTION_MESSAGE,
						null, 
						optionsTONECHANNEL,
						optionsTONECHANNEL[0]);
						
					if (n<0) return;
					TONECHANNEL = n+1;
				}
				n = JOptionPane.showOptionDialog(null,
					"Which sound format to use?",
					"Sound format selection",
					JOptionPane.YES_NO_OPTION,
					JOptionPane.QUESTION_MESSAGE,
					null,
					optionsSOUNDFORMAT,
					optionsSOUNDFORMAT[0]);
				if (n<0) return;
				SOUNDFORMAT = n+1;
				n = JOptionPane.showOptionDialog(null,
					"Which sound format to use?",
					"Sound format selection",
					JOptionPane.YES_NO_OPTION,
					JOptionPane.QUESTION_MESSAGE,
					null,
					optionsPROGRAMFORMAT,
					optionsPROGRAMFORMAT[0]);
				if (n<0) return;
				PROGRAMFORMAT = n+1;
				String s_label = JOptionPane.showInputDialog(
					null, 
					"Enter sound label", 
					"Which label (sound name) to use?", 
					JOptionPane.QUESTION_MESSAGE
				);
				if (s_label==null) return;
				s_label = "sfx_"+s_label;
				if (SOUNDFORMAT==1 && PROGRAMFORMAT==1) {
					// Supported COLECO BIOS sound format in ASM codes
					BufferedWriter o = SaveToASM();
					try
					{
						//o.write("	.module sound");
						//o.newLine();
						//o.newLine();
						if (data.mode == 0) {
							o.write(";	.globl  "+s_label+"_"+TONECHANNEL);
						} else {
							o.write(";	.globl  "+s_label+"_0");
							o.newLine();
							o.write(";	.globl  "+s_label+"_3");
						}
						o.newLine();
						o.newLine();
						//o.write("	.area _CODE");
						//o.newLine();
						//o.newLine();
						if (data.mode == 0) {
							o.write(s_label+"_"+TONECHANNEL+":");
							o.newLine();
							// Encoding loop - START
							int ch_code = TONECHANNEL*4*16;
							int i = data.startAt;
							while (i<=data.endAt) {
								AudioDatum datum = data.sequence[i];
								int duration = 1;
								int j = i+1;
								while (j<=data.endAt && datum.period == data.sequence[j].period && datum.attenuation == data.sequence[j].attenuation)
								{ j++; duration++; }
								i = j;
								String s = "   db ";
								s += "$"+DEC2HEX(ch_code)+","
								+ "$"+DEC2HEX(datum.period % 256)+","
								+ "$"+DEC2HEX(datum.attenuation*16 + (datum.period/256))+","+duration;
								o.write(s);
								o.newLine();
							}
							o.write("   db $"+DEC2HEX(ch_code+16));
							o.newLine();
							// Encoding loop - END
						} else {
							//--//
							// NOISE (VOLUME)
							o.write(s_label+"_0:");
							o.newLine();
							// Encoding loop - START
							int i = data.startAt;
							while (i<=data.endAt) {
								AudioDatum datum = data.sequence[i];
								int duration = 1;
								int j = i+1;
								while (j<=data.endAt && datum.attenuation == data.sequence[j].attenuation)
								{ j++; duration++; }
								i = j;
								String s = " db ";
								s += "$00,$00,$"+DEC2HEX(datum.attenuation*16 + data.mode*4 -1)+","+duration;
								o.write(s);
								o.newLine();
							}
							o.write(" db $10");
							o.newLine();
							// Encoding loop - END
							
							//--//
							// TONE #3 (FREQs)
							o.write(s_label+"_3:");
							o.newLine();
							// Encoding loop - START
							i = data.startAt;
							while (i<=data.endAt) {
								AudioDatum datum = data.sequence[i];
								int duration = 1;
								int j = i+1;
								while (j<=data.endAt && datum.period == data.sequence[j].period)
								{ j++; duration++; }
								i = j;
								String s = " db ";
								s += "$c0,$"
								+ DEC2HEX(datum.period % 256) + ",$"
								+ DEC2HEX(15*16 + (datum.period/256))+","+duration;
								o.write(s);
								o.newLine();
							}
							o.write(" db $d0");
							o.newLine();
							// Encoding loop - END
							
						}
						o.flush();
						o.close();
					} catch (FileNotFoundException err) {
						err.printStackTrace();
					} catch (IOException err) {
						err.printStackTrace();
					}
				} else {
					 JOptionPane.showMessageDialog(null, "Sorry, it's not supported in this version", "Oops!", JOptionPane.INFORMATION_MESSAGE);
				}
				/*
				JFileChooser chooser = new JFileChooser();
				chooser.setDialogTitle("Export Sound Effect");
				chooser.setFileSelectionMode(JFileChooser.FILES_ONLY);
				chooser.setFileFilter(new FileNameExtensionFilter("Sound Effects (.sfx)", "sfx"));
				if(chooser.showSaveDialog(null) == JFileChooser.APPROVE_OPTION) {
					File file = chooser.getSelectedFile();
					String filePath = file.getPath();
					if(!filePath.toLowerCase().endsWith(".sfx"))
					{
					    file = new File(filePath + ".sfx");
					}
					if(file.exists())
					{
						int actionDialog = JOptionPane.showConfirmDialog(chooser,"The file exists, overwrite?","Existing file",JOptionPane.YES_NO_CANCEL_OPTION);
						//JOptionPane.showConfirmDialog(this,"Replace existing file?","Existing file",JOptionPane.YES_NO_CANCEL_OPTION);
						// may need to check for cancel option as well
						if (actionDialog == JOptionPane.NO_OPTION || actionDialog == JOptionPane.CANCEL_OPTION) return;
					}
					try
					{
						//PrintWriter writer = new PrintWriter(file.getPath(), "UTF-8");
						BufferedWriter o = new BufferedWriter(new FileWriter(file));
						o.write("MODE "+data.mode);
						o.newLine();
						o.write("SIZE "+data.size);
						o.newLine();
						o.write("START "+data.startAt);
						o.newLine();
						o.write("END "+data.endAt);
						o.newLine();
						for (int i=data.startAt; i<=data.endAt; i++)
						{
							AudioDatum datum = data.sequence[i];
							o.write(""+datum.period+" "+datum.attenuation);
							o.newLine();
						}
						o.flush();
						o.close();
					} catch (FileNotFoundException err) {
						err.printStackTrace();
					} catch (IOException err) {
						err.printStackTrace();
					}
				}
				*/
			}          
		});
	}
	
	public String DEC2HEX(int value) {
		String result = Integer.toHexString(value);
		if (result.length() <2) result = "0"+result;
		return result;
	}
	
	static public BufferedWriter SaveToASM() {
		JFileChooser chooser = new JFileChooser();
		chooser.setDialogTitle("Export Sound Effect to ASM");
		chooser.setFileSelectionMode(JFileChooser.FILES_ONLY);
		chooser.setFileFilter(new FileNameExtensionFilter("ASM (.s)", "s"));
		if(chooser.showSaveDialog(null) == JFileChooser.APPROVE_OPTION) {
			File file = chooser.getSelectedFile();
			String filePath = file.getPath();
			if(!filePath.toLowerCase().endsWith(".s"))
			{
			    file = new File(filePath + ".s");
			}
			if(file.exists())
			{
				int actionDialog = JOptionPane.showConfirmDialog(chooser,"The file exists, overwrite?","Existing file",JOptionPane.YES_NO_CANCEL_OPTION);
				//JOptionPane.showConfirmDialog(this,"Replace existing file?","Existing file",JOptionPane.YES_NO_CANCEL_OPTION);
				// may need to check for cancel option as well
				if (actionDialog == JOptionPane.NO_OPTION || actionDialog == JOptionPane.CANCEL_OPTION) return null;
			}
			try
			{
				//PrintWriter writer = new PrintWriter(file.getPath(), "UTF-8");
				BufferedWriter o = new BufferedWriter(new FileWriter(file));
				return o;
			} catch (FileNotFoundException err) {
				err.printStackTrace();
			} catch (IOException err) {
				err.printStackTrace();
			}
		}
		return null;
	}
	
}

class LoadButton extends JButton {
	
	public AudioData data;
	public AudioPanel panel;
	
	public LoadButton(AudioData d, AudioPanel p) {
		super("Load");
		mouse();
		panel = p;
		setAudioData(d);
	}
	
	public void setAudioData(AudioData d) {
		data = d;
	}

	public void mouse() {
		addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				JFileChooser chooser = new JFileChooser();
				chooser.setDialogTitle("Load Sound Effect");
				chooser.setFileSelectionMode(JFileChooser.FILES_ONLY);
				chooser.setFileFilter(new FileNameExtensionFilter("Sound Effects (.sfx)", "sfx"));
				if(chooser.showOpenDialog(null) == JFileChooser.APPROVE_OPTION) {
					File file = chooser.getSelectedFile();
					String filePath = file.getPath();
					if(!filePath.toLowerCase().endsWith(".sfx"))
					{
					    file = new File(filePath + ".sfx");
					}
					if(file.exists())
					{
						try
						{
							String line;
							BufferedReader o = new BufferedReader(new FileReader(file));
							data.reset();
							int index = 0;
							while ((line = o.readLine()) != null) {
								String[] nameArray = line.split(" ");
								String label = nameArray[0];
								Boolean done = false;
								if (label.equals("MODE"))
								{
									data.mode = Integer.parseInt(nameArray[1]);
									done = true;
								}
								if (label.equals("SIZE"))
								{
									data.size = Integer.parseInt(nameArray[1]);
									done = true;
								}
								if (label.equals("START"))
								{
									data.startAt = Integer.parseInt(nameArray[1]);
									done = true;
								}
								if (label.equals("END"))
								{
									data.endAt = Integer.parseInt(nameArray[1]);
									done = true;
								}
								if (!done) {
									data.sequence[index].period = Integer.parseInt(nameArray[0]);
									data.sequence[index].attenuation = Integer.parseInt(nameArray[1]);
									index++;
								}
							}
							o.close();
						} catch (FileNotFoundException err) {
							err.printStackTrace();
						} catch (IOException err) {
							err.printStackTrace();
						}
						panel.repaint();
					}
				}
			}          
		});
	}
}

class SoundMode extends JComboBox {
	
	public AudioData data;
	
	public SoundMode(AudioData d) {
		setEditable(false);
		addItem("Tone");
		addItem("Periodic Noise");
		addItem("White Noise");
		setSelectedIndex(0);
		data = d;
		addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				data.mode = getSelectedIndex();
			}
		});
	}		
}

class CursorMode extends JComboBox {
	
	public AudioPanel panel;
	
	public CursorMode(AudioPanel p) {
		setEditable(false);
		addItem("Frequency");
		addItem("Volume");
		addItem("Start");
		addItem("End");
		setSelectedIndex(0);
		panel = p;
		addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.mode = getSelectedIndex();
			}
		});
	}
}

class FrequencyMode extends JComboBox {
	
	public AudioPanel panel;
	
	public FrequencyMode(AudioPanel p) {
		setEditable(false);
		addItem("Free Hand");
		addItem("Autotune");
		setSelectedIndex(0);
		panel = p;
		addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.autotune = (getSelectedIndex() == 1);
			}
		});
	}		
}

public class CVSoundFX {
    
	public static void main(String[] args) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				createAndShowGUI();
			}
		});
	}
    
	private static void createAndShowGUI() {
		//System.out.println("CV Sound FX? "+ SwingUtilities.isEventDispatchThread());
		JFrame f = new JFrame("Coleco Sound Effects");
		f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		f.setResizable(false);
		AudioData d = new AudioData();
		AudioChip chip = new AudioChip();
		AudioPanel ap = new AudioPanel(d);
		new Thread(chip).start();
		f.add(ap,BorderLayout.CENTER );
		JPanel p = new JPanel();
		p.setLayout(new FlowLayout());
		p.add(new PlayButton(d,chip));
		p.add(new SoundMode(d));
		p.add(new FrequencyMode(ap));
		p.add(new CursorMode(ap));
		p.add(new SaveButton(d));
		p.add(new LoadButton(d,ap));
		p.add(new ExportButton(d));
		p.add(new ResetButton(d,ap));
		f.add(p,BorderLayout.NORTH );
		f.pack();
		//f.setSize(250,250);
		f.setVisible(true);
	}
}
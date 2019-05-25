/*******************************************************************************
 * Cushion - A library to help state transition matrix design
 * 
 * This library aims to process the table which is state transition matrix
 * designed on the D language source code.
 * Tables written in csv file will be converted to D language source code at
 * compile time.
 * 
 * Examples:
 * -----
 * 
 * -----
 * 
 * Copyright: © 2019, SHOO
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 * Author: SHOO
 */
module cushion;

public import cushion.core;
public import cushion.csvdecoder;
public import cushion.handler;
public import cushion.flow;

Introduction

This is a new version push down testing tool based on the old one (Notes Link). Compare to the old tool, this tool has following modifications:

1. Used XML file instead of *.lst files as input

2. Added function elimination checking. (This feature still need to be improved.)

3. Added internal function checking. (When optimized statement contains "$INTERNAL_FUNC$", this tool will trace the explain plan statement and find out what internal function used at here.)

4. Added db2exfmt plan output option. (After this option enabled, db2exfmt plan will be generated for each explain plan statement.)

5. Plan to add information capturing feature. (Unsupported currently)


Since we used XML file as testing input, we can put more data in the XML file, such as function return type and special function arguments for special functions, we no longer need two different list as input, and the logic in the tool can be extremely simplified.


XML file structure

The xml file looks like this:

<function_mappings>
  <brief>...</brief>
  <long>...</long>
  ...
  <function_array name="..." lengthname="...">
    <long>...</long>
    <function name="SYSIBM.YEAR">
      <arg value="SYSIBM.DECIMAL" />
      <pure_name value="YEAR" />
      <remote_function_name value="SYSIBM.YEAR(:1P)" />
      <return_type value="SYSIBM.INTEGER" />
      <schema value="SYSIBM" />
      <test_arg pos="1">DCM_DATETIME</test_arg>
      ...
    </function>
    <function name="SYSIBM.&lt;" is_operator="Y" is_relational_operator="Y">
      <arg value="SYSIBM.BIGINT" />
      <arg value="SYSIBM.DOUBLE" />
      <pure_name value="&lt;" />
      <remote_function_name value="(:1P &lt; :2P)" />
      <return_type value="SYSIBM.BOOLEAN" />
      <schema value="SYSIBM" />
      ...
    </function>
    <function name="SYSIBM.MIN" is_aggregation_function="Y">
      <arg value="SYSIBM.VARGRAPHIC" />
      <pure_name value="MIN" />
      <remote_function_name value="SYSIBM.MIN(:D :1P)" />
      <return_type value="SYSIBM.VARGRAPHIC" />
      <schema value="SYSIBM" />
      ...
    </function>
    ...
  </function_array>
</function_mappings>

From the example, you can see there are several attributes and sub-elements marked as blue, actually they are the attributes of a function which we cared in push down testing.

Every function should have following attributes:
Attribute


name
The name of the function


schema
The schema of the function


pure_name
This is the function name of the function, without schema prefix.


return_type
This is the return type of the function.


remote_function_name
This is the remote format of the function, we use it at here to check whether the function pushed down.


Description
Almost all functions have this attribute:
Attribute
Description


arg
This is the function parameter type of the function. most functions has parameters, so most function has this attribute. If a function has more than one parameter, then more than one "arg" attribute should be here, and they appear with the same sequence as the function parameters does.



Some functions may have following attributes:
Attribute
Description


test_arg
This is the special function argument for this function when doing push down testing. Some function may have special limitation to its arguments (such as function SYSIBM.DATE (SYSIBM.CHAR) can only process CHAR data with valid date format). Under these circumstance, this attribute should be used.
CAUTION: This attribute has an "pos" attribute, which is an index indicates the position of the argument for the function, the index starts from "1" but not "0".


is_operator
This function is an operator, which can only have two parameters and has in-fix  invoking format.


is_relational_operator
This function is a relational operator, which can not be used in phase one testing.


is_aggregation_function
This function is an aggregation function, which cannot be used in phase two testing.



The testing tool will parse the whole XML file into a HASH REF, and then start the testing process based on the attributes of each function item.


Tool configurations

At the top of the testing tool (start.pl), there are several configuration points, they looks like this:

my $test_cfg =
{
    # Pre-test recording
    record_system_info => 1,
    record_environment => 1,
    record_dbm_config => 1,
    record_db_configs => 1,
    record_db2set => 1,
    record_info_directory_path => "info",

    # In-test recording
    record_db2exfmt_plan => 1,
    db2exfmt_plan_directory_path => "plan",

    # In-test processing configurations
    check_function_elimination => 1,
    trace_for_internal_func => 1,
    trace_for_internal_func_mask => "*.*.SQLNQ.sqlnq_sat::get_remote_function.*",
    trace_directory_path => "trace",
};

my $output_cfg =
{
    # Report related configurations
    report_mainpage_template_path => "report_res/mainpage.html",
    report_table_template_path => "report_res/table.html",
    report_row_template_path => "report_res/row.html",
    report_directory_path => "report",

    generate_temporary_report => 1,
    temporary_report_frequency => 10, # Cannot be 0 at here.
    temporary_report_filename => "temp.html",

    final_report_filename => "final.html",
};

my $db_cfg =
{
    feddb_name => "FEDDB",
    remdb_name => "DSDB",
    feddb_schema => "IIFVT66",
    remdb_schema => "IIFVT66",

    wrapper => "DRDA",
    srv_name => "PDSERVER",

    tb_name => "T1",
    nk_name => "N1",
};

You can modify them to control the input, testing process, output and database information of the tool.


Download and usage

Check out the tool at here ==>  pushdown_v0.2_140626.zip  

Usage:

Step 1: Run db2 -tvf prepareDB.clp to create db, wrapper, server, user mapping, table and nickname.

Step 2: Run db2 call sysproc.sysinstallobjects ('EXPLAIN', 'C', null, '<SCHEMA_NAME>') to generate tables for explain plan.

Step 3: Run perl start.pl <XML_FILE_PATH> to start the testing process.

Notice: Make sure database information is correct in start.pl.


XML file generating

The xml file should be written manually so that return_type and test_arg can be precisely specified. But if you want to generate it from the old *.lst files any way, it's still an optional method provided at here.

Check out the tool at here ==>  genXmlFromLst.zip  

Usage:

Step 1: Replace these two *.lst files with yours, OR change the tool (genXmlFromLst.pl) to let it accept command line parameter.

Step 2: Run genXmlFromLst.pl and redirect STDOUT to an XML file which is the file you want to generate.


Report Example


 pshdwn_rlt.zip  

This result was generated with an earlier version of this tool, but the modification between it with the latest version's was very small.


Perfect thoughts, imperfect tool

At the very beginning, we plan to use the XML file not only for push down testing but also sqqg function mapping header file generating.

And the XML file initially looks like this:

<function_mappings>
   <brief>Net8</brief>
   <long>
       For function mappings:
                      Net8 Wrapper default function mappings
            (stored in array called SQLQG_Net8_function_defaults)
                          /                   \
       Version 7.3 overrides                Version 8 overrides
       (stored in array called              (stored in array called
        SQLQG_Net8_73_function_defaults)   SQLQG_Net8_73_function_defaults)

       In set_my_default_remote_function_mappings, we add all of the function mappings
       in the SQLQG_Net8_function_defaults array to the function mappings hash table.
       Then, based on the server version, we add all of the function mappings in the
       server version array to the function mappings hash table.
   </long>
   <prefix>sqlqg_net8</prefix>
   <public_header>sqlqg_wrapper.h</public_header>
   <public_header>sqlqg.h</public_header>
   <public_header>sqlqg_server.h</public_header>
   <public_header>sqlqg_server_attrs.h</public_header>
   <public_header>sqlno_cost_const.h</public_header>
   <private_header>sqltqg_net8.h</private_header>
   <function_array name="SQLQG_Net8_function_defaults" lengthname="SQLQG_Net8_NUM_DEFAULT_FUNCTION_MAPPINGS">
     <long>
  Static array of Oracle function mapping overrides for server
  versions 8.1.x and 8.2.x
     </long>
     <function name="./" disable="N">
      <local_signature value="SYSIBM./" />
      <arg value="INTEGER_EXP1" />
      <arg value="INTEGER_EXP1" />
      <remote_function_name value="TRUNC(:1P / :2P)" />
      <remote_result_type value="SQLQG_UNKNOWN" />
      <ios_per_invoc value="0" />
      <insts_per_invoc value="LFLT(SQLNO_INSTS_PER_COMPARE)" />
      <ios_per_arg_byte value="0" />
      <insts_per_arg_byte value="0" />
      <percent_arg_byte value="0" />
      <initial_ios value="0" />
      <initial_insts value="0" />
     </function>

     <function name="SYSIBM.SUBSTRB" disable="N">
      <local_signature value="SYSIBM.SUBSTRB" />
      <local_signature value="SYSIBM.SUBSTRB" />
      <arg value="CHAR_ALL_EXP1" />
      <arg value="INTEGER_EXP1" />
      <arg value="INTEGER_EXP1" />
      <remote_function_name value="SUBSTRB(:1P, :2P, :3P)" />
     </function>
   </function_array>

   <function_array name="SQLQG_Net8_8_function_defaults" lengthname="SQLQG_Net8_8_NUM_DEFAULT_FUNCTION_MAPPINGS">
     <function name="SYSIBM.SUBSTRB" disable="N">
      <local_signature value="SYSIBM.SUBSTRB" />
      <arg value="CHAR_ALL_EXP1" />
      <arg value="INTEGER_EXP1" />
      <arg value="INTEGER_EXP1" />
      <remote_function_name value="SUBSTRB(:1P, :2P, :3P)" />
     </function>
   </function_array>
</function_mappings>


As you can see from the XML file, the value for arg attributes of each function item is not a real DB2 type (such as SYSIBM.INTEGER), it is something like a macro, and each macro like that will map to a list of types. They have mapping relation as below.

INTEGER_EXP = "SYSIBM.SMALLINT,SYSIBM.INTEGER";
INTEGER_EXP1 = "SYSIBM.SMALLINT,SYSIBM.INTEGER,SYSIBM.BIGINT";
DECIMAL_EXP = "SYSIBM.DOUBLE,SYSIBM.REAL,SYSIBM.DECIMAL";
DECIMAL_EXP1 = "SYSIBM.DOUBLE,SYSIBM.REAL,SYSIBM.DECIMAL,SYSIBM.DECFLOAT";
TIMESTAMP_EXP = "SYSIBM.DATE,SYSIBM.TIME,SYSIBM.TIMESTMP";
CHAR_EXP = "SYSIBM.CHAR,SYSIBM.VARCHAR";
CHAR_EXP1 = "SYSIBM.CHAR,SYSIBM.VARCHAR,SYSIBM.CLOB";
UNICHAR_EXP = "SYSIBM.GRAPHIC,SYSIBM.VARGRAPHIC";
UNICHAR_EXP1 = "SYSIBM.GRAPHIC,SYSIBM.VARGRAPHIC,SYSIBM.DBCLOB";
CHAR_ALL_EXP = "SYSIBM.CHAR,SYSIBM.VARCHAR,SYSIBM.GRAPHIC,SYSIBM.VARGRAPHIC";
CHAR_ALL_EXP1 = "SYSIBM.CHAR,SYSIBM.VARCHAR,SYSIBM.CLOB,SYSIBM.GRAPHIC,SYSIBM.VARGRAPHIC,SYSIBM.DBCLOB";


So, the second function item SYSIBM.SUBSTRB in the XML file stands for more than one function signature.

Since,

CHAR_ALL_EXP1 -> SYSIBM.CHAR , SYSIBM.VARCHAR , SYSIBM.CLOB , SYSIBM.GRAPHIC , SYSIBM.VARGRAPHIC , SYSIBM.DBCLOB   (6 types)
INTEGER_EXP1 -> SYSIBM.SMALLINT , SYSIBM.INTEGER , SYSIBM.BIGINT (3 types)

This single function item in the XML file stands for 54(6 * 3 * 3) different function signatures.

It's good to write XML file in this way, 'cuz it can extremely decrease the size of the XML file as same as human efforts.

BUT, I have at least two reasons to not use it in push down testing.

1. Different from header file generating, push down testing needs function return type, and different function signatures (even has the same function name) may have different return types, so it is hard to specify function return type for each function signature if the XML file wrote like this.

2. Different from header file generating, push down testing may need to specify function arguments for some special function signatures,  and it is hard to do it if we write the XML file this way.

So, the macro-like XML organization method is NOT BAD, but NOT SUITABLE for push down testing. 


Further Support

Since I left IBM, if you want to get support for this tool from me, you'll have to contact me by my public e-mail or cell phone.

My public e-mail address: ericwang427@gmail.com
My cell phone number: +86 185 1423 5596

(EOF)

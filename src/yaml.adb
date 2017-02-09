with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;

with Interfaces.C.Strings;

package body YAML is

   use type C_Int;

   procedure Deallocate is new Ada.Unchecked_Deallocation
     (String, String_Access);
   procedure Deallocate is new Ada.Unchecked_Deallocation
     (Document_Type, Document_Access);

   ----------------------
   -- C symbol imports --
   ----------------------

   procedure C_Document_Delete (Document : in out C_Document_T)
      with Import, Convention => C, External_Name => "yaml_document_delete";

   function C_Document_Get_Root_Node
     (Document : C_Document_Access) return C_Node_Access
      with
         Import,
         Convention    => C,
         External_Name => "yaml_document_get_root_node";

   function C_Document_Get_Node
     (Document : C_Document_Access;
      Index    : C_Int) return C_Node_Access
   with
      Import, Convention => C, External_Name => "yaml_document_get_node";

   function C_Parser_Initialize (Parser : C_Parser_Access) return C_Int
      with Import, Convention => C, External_Name => "yaml_parser_initialize";

   function Allocate_Parser return C_Parser_Access
      with Import, Convention => C, External_Name => "yaml__allocate_parser";

   function C_Parser_Load
     (Parser : C_Parser_Access; Document : C_Document_Access) return C_Int
      with Import, Convention => C, External_Name => "yaml_parser_load";

   procedure C_Parser_Set_Input_String
     (Parser : C_Parser_Access;
      Input  : C_Char_Access;
      Size   : Interfaces.C.size_t)
      with
         Import,
         Convention    => C,
         External_Name => "yaml_parser_set_input_string";

   procedure C_Parser_Set_Input_File
     (Parser : C_Parser_Access;
      File   : C_File_Ptr)
      with Import,
           Convention    => C,
           External_Name => "yaml_parser_set_input_file";

   procedure C_Parser_Delete (Parser : C_Parser_Access)
      with Import, Convention => C, External_Name => "yaml_parser_delete";

   procedure Deallocate_Parser (Parser : C_Parser_Access)
      with Import, Convention => C, External_Name => "yaml__deallocate_parser";

   function C_Fopen
     (Path, Mode : Interfaces.C.Strings.chars_ptr) return C_File_Ptr
      with Import, Convention => C, External_Name => "fopen";

   function C_Fclose (Stream : C_File_Ptr) return C_Int
      with Import, Convention => C, External_Name => "fclose";

   -------------
   -- Helpers --
   -------------

   function Convert (S : String_Access) return C_Char_Access;

   procedure Discard_Input
     (Parser        : in out Parser_Type'Class;
      Re_Initialize : Boolean);
   --  Free input holders in parser and delete the C YAML parser. If
   --  Re_Initialize, also call Initialize_After_Allocation.

   function Get_Node
     (Document : Document_Type'Class; Index : C_Int) return Node_Ref;
   --  Wrapper around C_Document_Get_Node. Raise a Constraint_Error if Index is
   --  out of range.

   procedure Initialize_After_Allocation (Parser : in out Parser_Type'Class);
   --  Initialize the C YAML parser and assign proper defaults to input holders
   --  in Parser.

   function Wrap
     (Document : Document_Type'Class; N : C_Node_Access) return Node_Ref
   is
     ((Node => N, Document => Document'Unrestricted_Access));

   function Wrap (M : C_Mark_T) return Mark_Type is
     ((Line => Natural (M.Line) + 1, Column => Natural (M.Column) + 1));

   function Convert (S : String_Access) return C_Char_Access is
      Char_Array : C_Char_Array with Address => S.all'Address;
   begin
      return Char_Array'Unrestricted_Access;
   end Convert;

   function Get_Node
     (Document : Document_Type'Class; Index : C_Int) return Node_Ref
   is
      N : constant C_Node_Access :=
         C_Document_Get_Node (Document.C_Doc'Unrestricted_Access, Index);
   begin
      if N = null then
         raise Constraint_Error;
      end if;
      return Wrap (Document, N);
   end Get_Node;

   procedure Initialize_After_Allocation (Parser : in out Parser_Type'Class) is
   begin
      if C_Parser_Initialize (Parser.C_Parser) /= 1 then
         --  TODO: determine a good error handling scheme
         raise Program_Error;
      end if;

      Parser.Input_Encoding := Any_Encoding;
      Parser.Input_String := null;
      Parser.Input_File := No_File_Ptr;
   end Initialize_After_Allocation;

   procedure Discard_Input
     (Parser        : in out Parser_Type'Class;
      Re_Initialize : Boolean) is
   begin
      C_Parser_Delete (Parser.C_Parser);
      Deallocate (Parser.Input_String);
      if Parser.Input_File /= No_File_Ptr
         and then C_Fclose (Parser.Input_File) /= 0
      then
         raise File_Error;
      end if;

      if Re_Initialize then
         Initialize_After_Allocation (Parser);
      end if;
   end Discard_Input;

   ----------
   -- Misc --
   ----------

   overriding procedure Initialize (Document : in out Document_Type) is
   begin
      Document.Ref_Count := 0;
      Document.To_Delete := False;
   end Initialize;

   overriding procedure Finalize (Document : in out Document_Type) is
   begin
      if Document.To_Delete then
         C_Document_Delete (Document.C_Doc);
         Document.To_Delete := False;
      end if;
   end Finalize;

   overriding procedure Adjust (Handle : in out Document_Handle) is
   begin
      Handle.Inc_Ref;
   end Adjust;

   overriding procedure Finalize (Handle : in out Document_Handle) is
   begin
      Handle.Dec_Ref;
   end Finalize;

   procedure Inc_Ref (Handle : in out Document_Handle'Class) is
   begin
      if Handle /= No_Document_Handle then
         Handle.Document.Ref_Count := Handle.Document.Ref_Count + 1;
      end if;
   end Inc_Ref;

   procedure Dec_Ref (Handle : in out Document_Handle'Class) is
   begin
      if Handle /= No_Document_Handle then
         declare
            D : Document_Access := Handle.Document;
         begin
            D.Ref_Count := D.Ref_Count - 1;
            if D.Ref_Count = 0 then
               Deallocate (D);
            end if;
         end;
      end if;
   end Dec_Ref;

   overriding procedure Initialize (Parser : in out Parser_Type) is
   begin
      Parser.C_Parser := Allocate_Parser;
      Initialize_After_Allocation (Parser);
   end Initialize;

   overriding procedure Finalize (Parser : in out Parser_Type) is
   begin
      Discard_Input (Parser, False);
      Deallocate_Parser (Parser.C_Parser);
   end Finalize;

   -----------------------
   --  Public interface --
   -----------------------

   function Create return Document_Handle is
      D : constant Document_Access := new Document_Type;
   begin
      D.Ref_Count := 1;
      return (Ada.Finalization.Controlled with Document => D);
   end Create;

   function Root_Node (Document : Document_Type'Class) return Node_Ref is
   begin
      return Wrap
        (Document,
         C_Document_Get_Root_Node (Document.C_Doc'Unrestricted_Access));
   end Root_Node;

   function Start_Mark (Document : Document_Type'Class) return Mark_Type is
   begin
      return Wrap (Document.C_Doc.Start_Mark);
   end Start_Mark;

   function End_Mark (Document : Document_Type'Class) return Mark_Type is
   begin
      return Wrap (Document.C_Doc.End_Mark);
   end End_Mark;

   function Kind (Node : Node_Ref'Class) return Node_Kind is
   begin
      return Node.Node.Kind;
   end Kind;

   function Start_Mark (Node : Node_Ref'Class) return Mark_Type is
   begin
      return Wrap (Node.Node.Start_Mark);
   end Start_Mark;

   function End_Mark (Node : Node_Ref'Class) return Mark_Type is
   begin
      return Wrap (Node.Node.End_Mark);
   end End_Mark;

   function Value (Node : Node_Ref'Class) return UTF8_String is
      Data   : C_Node_Data renames Node.Node.Data;
      Result : UTF8_String (1 .. Natural (Data.Scalar.Length))
         with Address => Data.Scalar.Value.all'Address;
   begin
      return Result;
   end Value;

   function Length (Node : Node_Ref'Class) return Natural is
      use C_Node_Item_Accesses, C_Node_Pair_Accesses;
      Data : C_Node_Data renames Node.Node.Data;
   begin
      return
        (case Kind (Node) is
         when Sequence_Node => Natural
           (Data.Sequence.Items.Seq_Top - Data.Sequence.Items.Seq_Start),
         when Mapping_Node  => Natural
           (Data.Mapping.Pairs.Map_Top - Data.Mapping.Pairs.Map_Start),
         when others => raise Program_Error);
   end Length;

   function Item (Node : Node_Ref'Class; Index : Positive) return Node_Ref
   is
      use C_Node_Item_Accesses;
      Data : C_Node_Data renames Node.Node.Data;
      Item : constant C_Node_Item_Access :=
         Data.Sequence.Items.Seq_Start + C_Ptr_Diff (Index - 1);
   begin
      return Get_Node (Node.Document.all, Item.all);
   end Item;

   function Item (Node : Node_Ref'Class; Index : Positive) return Node_Pair
   is
      use C_Node_Pair_Accesses;
      Data : C_Node_Data renames Node.Node.Data;
      Pair : constant C_Node_Pair_Access :=
         Data.Mapping.Pairs.Map_Start + C_Ptr_Diff (Index - 1);
   begin
      return (Key   => Get_Node (Node.Document.all, Pair.Key),
              Value => Get_Node (Node.Document.all, Pair.Value));
   end Item;

   function Item (Node : Node_Ref'Class; Key : UTF8_String) return Node_Ref
   is
   begin
      for I in 1 .. Length (Node) loop
         declare
            Pair : constant Node_Pair := Item (Node, I);
         begin
            if Kind (Pair.Key) = Scalar_Node
               and then Value (Pair.Key) = Key
            then
               return Pair.Value;
            end if;
         end;
      end loop;
      return No_Node_Ref;
   end Item;

   function Has_Input (P : Parser_Type'Class) return Boolean is
   begin
      return P.Input_String /= null or else P.Input_File /= No_File_Ptr;
   end Has_Input;

   procedure Set_Input_String
     (Parser   : in out Parser_Type'Class;
      Input    : String;
      Encoding : Encoding_Type)
   is
   begin
      Parser.Input_Encoding := Encoding;
      Deallocate (Parser.Input_String);
      Parser.Input_String := new String'(Input);
      C_Parser_Set_Input_String
        (Parser.C_Parser,
         Convert (Parser.Input_String),
         Parser.Input_String'Length);
   end Set_Input_String;

   procedure Set_Input_File
     (Parser   : in out Parser_Type'Class;
      Filename : String;
      Encoding : Encoding_Type)
   is
      use Interfaces.C.Strings;

      C_Mode     : chars_ptr := New_String ("r");
      C_Filename : chars_ptr := New_String (Filename);
      File       : constant C_File_Ptr := C_Fopen (C_Filename, C_Mode);
   begin
      Free (C_Mode);
      Free (C_Filename);

      if File = No_File_Ptr then
         raise File_Error;
      end if;

      Deallocate (Parser.Input_String);
      Parser.Input_Encoding := Encoding;
      Parser.Input_File := File;
      C_Parser_Set_Input_File (Parser.C_Parser, Parser.Input_File);
   end Set_Input_File;

   procedure Discard_Input (Parser : in out Parser_Type'Class) is
   begin
      Discard_Input (Parser, True);
   end Discard_Input;

   procedure Load
     (Parser   : in out Parser_Type'Class;
      Document : in out Document_Type'Class) is
   begin
      Document.Finalize;
      if C_Parser_Load
        (Parser.C_Parser, Document.C_Doc'Unrestricted_Access) /= 1
      then
         --  TODO: determine a good error handling scheme
         raise Program_Error;
      end if;
      Document.To_Delete := True;
   end Load;

end YAML;

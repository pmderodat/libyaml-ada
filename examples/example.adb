with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;

with YAML;

procedure Example is

   procedure Process_String (S : String);
   procedure Process_File (Filename : String);
   procedure Process (D : YAML.Document_Type);
   procedure Put (N : YAML.Node_Ref; Indent : Natural);

   procedure Process_String (S : String) is
      P : YAML.Parser_Type;
      D : YAML.Document_Type;
   begin
      P.Set_Input_String (S, YAML.UTF8_Encoding);
      P.Load (D);
      Process (D);
   end Process_String;

   procedure Process_File (Filename : String) is
      P : YAML.Parser_Type;
      D : constant YAML.Document_Handle := YAML.Create;
   begin
      P.Set_Input_File (Filename, YAML.UTF8_Encoding);
      P.Load (D.Document.all);
      Process (D.Document.all);
   end Process_File;

   procedure Process (D : YAML.Document_Type) is
      N : constant YAML.Node_Ref := D.Root_Node;
   begin
      Put (N, 0);
      New_Line;
   end Process;

   procedure Put (N : YAML.Node_Ref; Indent : Natural) is
      Prefix : constant String := (1 .. Indent => ' ');
   begin
      case YAML.Kind (N) is
         when YAML.No_Node =>
            Put_Line (Prefix & "<null>");

         when YAML.Scalar_Node =>
            Put_Line (Prefix & String (N.Value));

         when YAML.Sequence_Node =>
            for I in 1 .. N.Length loop
               Put_Line (Prefix & "- ");
               Put (N.Item (I), Indent + 2);
            end loop;

         when YAML.Mapping_Node =>
            Put_Line ("Pairs:");
            for I in 1 .. N.Length loop
               declare
                  Pair : constant YAML.Node_Pair := N.Item (I);
               begin
                  Put (Prefix & "Key:");
                  Put (Pair.Key, Indent + 2);
                  Put (Prefix & "Value:");
                  Put (Pair.Value, Indent + 2);
               end;
            end loop;
      end case;
   end Put;

begin
   if Argument_Count = 0 then
      Process_String ("1");
      Process_String ("[1, 2, 3, a, null]");
      Process_String ("foo: 1");
   else
      for I in 1 .. Argument_Count loop
         Process_File (Argument (I));
      end loop;
   end if;
end Example;

using System;
using System.Reflection;

namespace app
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("FX_DEPS_FILE           : " + AppContext.GetData("FX_DEPS_FILE"));
            foreach (var deps in ((string)AppContext.GetData("APP_CONTEXT_DEPS_FILES")).Split(";"))
            {
                Console.WriteLine("APP_CONTEXT_DEPS_FILES : " + deps);
            }

            var assembly = Assembly.Load("hs");
            var type = assembly.GetType("hs.Program");
            var method = type.GetMethod("Main");
            method.Invoke(null, new object[] { args });
        }
    }
}

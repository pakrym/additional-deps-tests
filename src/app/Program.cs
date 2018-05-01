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
            foreach (var arg in args)
            {
                var assembly = Assembly.Load(arg);
                var type = assembly.GetType("hs.Program");
                var method = type.GetMethod("Main");
                method.Invoke(null, new object[] { args });
            }
            try
            {
                var assembly = Assembly.Load("Microsoft.Extensions.DependencyInjection.Abstractions");
                Console.WriteLine("COMMON DEPENDENCY      : " + assembly.CodeBase + " " + assembly.GetName().Version);
            }
            catch
            {
                //ignore
            }
        }
    }
}

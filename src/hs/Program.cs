using System;
using System.Reflection;

namespace hs
{
    class Program
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("HOSTING_STARTUP      : " + Assembly.GetExecutingAssembly().Location);
        }
    }
}

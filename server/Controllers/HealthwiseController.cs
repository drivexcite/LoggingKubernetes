using System;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace FlashyService.Controllers
{
    [ApiController]
    public class HealthwiseController : ControllerBase
    {
        private static Random Random { get; } = new Random();

        private ILogger<HealthwiseController> Log { get; set; }

        public HealthwiseController(ILogger<HealthwiseController> log)
        {
            Log = log;
        }

        [HttpGet]
        [Route("doIt")]
        public IActionResult DoIt()
        {
            var random = Random.Next();

            if (random % 2 == 0)
            {
                Log.LogInformation($"Everything seems cool: {random}");
                return Ok();
            }

            if (random % 3 == 0)
            {
                Log.LogWarning($"Things are starting to look dumb: {random}");
                return NotFound();
            }

            if (random % 5 == 0)
            {
                Log.LogError($"This is real weird: {random}");
                return BadRequest();
            }

            Log.LogError($"This is not at all what I was expecting: {random}");
            throw new ArgumentException($"{random} is a dumb number");
        }
    }
}

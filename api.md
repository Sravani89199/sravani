This need to add in XML file:-
<GenerateDocumentationFile>true</GenerateDocumentationFile>

Need to install packages:-
Microsoft.EntityFrameworkCore
Microsoft.EntityFrameworkCore.Design
Microsoft.EntityFrameworkCore.Tools
MySQL.EntityFrameworkCore
Microsoft.AspNetCore.Authentication.JwtBearer
Asp.Versioning.Mvc
Asp.Versioning.Mvc.ApiExplorer


Models/Student.cs:
namespace Swagger_DocumentationAPI.Models
{
    public class Student
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int Age { get; set; }
        public string Email { get; set; } = string.Empty;
        public string Course { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}

DTOs:
LoginDTO.cs
using System.ComponentModel.DataAnnotations;

namespace Swagger_DocumentationAPI.DTOs
{
    public class LoginDTO
    {
        [Required]
        public string Username { get; set; } = string.Empty;

        [Required]
        public string Password { get; set; } = string.Empty;
    }
}

PagedResultDTO.cs:
namespace Swagger_DocumentationAPI.DTOs
{
    public class PagedResultDTO<T>
    {
        public List<T> Data { get; set; } = new();
        public int PageNumber { get; set; }
        public int PageSize { get; set; }
        public int TotalRecords { get; set; }
        public int TotalPages { get; set; }
    }
}

StudentDTO.cs:
using System.ComponentModel.DataAnnotations;

namespace Swagger_DocumentationAPI.DTOs
{
    public class StudentDTO
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Name is required.")]
        [StringLength(100, MinimumLength = 3,
            ErrorMessage = "Name must be between 3 and 100 characters.")]
        public string Name { get; set; } = string.Empty;

        [Required(ErrorMessage = "Age must be between 18 to 50.")]
        [Range(18, 50)]
        public int Age { get; set; }

        [Required(ErrorMessage = "Email is required.")]
        [EmailAddress(ErrorMessage = "Invalid email address.")]
        public string Email { get; set; } = string.Empty;

        [Required]
        [StringLength(50)]
        public string Course { get; set; } = string.Empty;
    }
}

StudentQueryDTO.cs:
namespace Swagger_DocumentationAPI.DTOs
{
    public class StudentQueryDTO
    {
        public int PageNumber { get; set; } = 1;
        public int PageSize { get; set; } = int.MaxValue;
        public string? Search { get; set; }
        public string SortBy { get; set; } = "id";
        public string SortOrder { get; set; } = "asc";
    }
}

StudentRepDTO.cs:
namespace Swagger_DocumentationAPI.DTOs
{
    public class StudentRepDTO
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int Age { get; set; }
        public string Email { get; set; } = string.Empty;
        public string Course { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}

Data/StudentDbContext.cs:
using Microsoft.EntityFrameworkCore;
using Swagger_DocumentationAPI.Models;

namespace Swagger_DocumentationAPI.Data
{
    public class StudentDbContext : DbContext
    {
        public StudentDbContext(DbContextOptions<StudentDbContext> options)
            : base(options)
        {
        }
        public DbSet<Student> Students { get; set; }
    }
}

Middleware:
ExceptionHandlingMiddleware.cs:
using System.Text.Json;

namespace Swagger_DocumentationAPI.Middleware
{
    public class ExceptionHandlingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<ExceptionHandlingMiddleware> _logger;

        public ExceptionHandlingMiddleware(
            RequestDelegate next,
            ILogger<ExceptionHandlingMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }
        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled exception while processing {Method} {Path}",
                    context.Request.Method,
                    context.Request.Path);

                if (context.Response.HasStarted)
                {
                    throw;
                }

                context.Response.Clear();
                context.Response.ContentType = "application/json";

                var (statusCode, message) = ex switch
                {
                    KeyNotFoundException => (StatusCodes.Status404NotFound, ex.Message),

                    ArgumentException => (StatusCodes.Status400BadRequest, ex.Message),

                    InvalidOperationException => (StatusCodes.Status400BadRequest, ex.Message),

                    _ => (StatusCodes.Status500InternalServerError, ex.Message)
                };

                context.Response.StatusCode = statusCode;

                await context.Response.WriteAsync(JsonSerializer.Serialize(new
                {
                    statusCode,
                    message,
                    timestamp = DateTime.UtcNow
                }));
            }
        }
    }
}

RequestTimeMiddleware.cs:
using System.Diagnostics;

namespace Swagger_DocumentationAPI.Middleware
{
    public class RequestTimeMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<RequestTimeMiddleware> _logger;

        public RequestTimeMiddleware(
            RequestDelegate next,
            ILogger<RequestTimeMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var stopwatch = Stopwatch.StartNew();

            try
            {
                await _next(context);
            }
            finally
            {
                stopwatch.Stop();

                _logger.LogInformation(
                    "Request {Method} {Path} returned {StatusCode} in {ElapsedMilliseconds} ms",
                    context.Request.Method,
                    context.Request.Path,
                    context.Response.StatusCode,
                    stopwatch.ElapsedMilliseconds);
            }
        }
    }
}



Repositories:
IStudentRepository.cs:
using Swagger_DocumentationAPI.DTOs;
using Swagger_DocumentationAPI.Models;

namespace Swagger_DocumentationAPI.Repositories
{
    public interface IStudentRepository
    {
        Task<PagedResultDTO<StudentRepDTO>> GetStudentsAsync(StudentQueryDTO query);
        Task<List<Student>> GetAllAsync();
        Task<Student?> GetByIdAsync(int id);
        Task<List<Student>> AddAsync(List<Student> students);
        Task<Student?> UpdateAsync(int id, Student student);
        Task<List<Student>> UpdateMultipleAsync(List<Student> students);
        Task<bool> DeleteAsync(int id);
    }
}

StudentRepository.cs:
using Microsoft.EntityFrameworkCore;
using Swagger_DocumentationAPI.Data;
using Swagger_DocumentationAPI.DTOs;
using Swagger_DocumentationAPI.Models;

namespace Swagger_DocumentationAPI.Repositories
{
    public class StudentRepository : IStudentRepository
    {
        private readonly StudentDbContext _context;

        public StudentRepository(StudentDbContext context)
        {
            _context = context;
        }
        public async Task<PagedResultDTO<StudentRepDTO>> GetStudentsAsync(StudentQueryDTO query)
        {
            IQueryable<Student> students = _context.Students.AsNoTracking();

            if (!string.IsNullOrWhiteSpace(query.Search))
            {
                string search = query.Search.Trim();

                students = students.Where(s =>
                s.Name.Contains(search) ||
                s.Email.Contains(search) ||
                s.Course.Contains(search));
            }

            int totalRecords = await students.CountAsync();

            bool descending = query.SortOrder.Equals("desc", StringComparison.OrdinalIgnoreCase);

            students = query.SortBy.ToLower() switch
            {
                "name" => descending
                ? students.OrderByDescending(s => s.Name)
                : students.OrderBy(s => s.Name),

                "age" => descending
                ? students.OrderByDescending(s => s.Age)
                : students.OrderBy(s => s.Age),

                "email" => descending
                ? students.OrderByDescending(s => s.Email)
                : students.OrderBy(s => s.Email),

                "course" => descending
                ? students.OrderByDescending(s => s.Course)
                : students.OrderBy(s => s.Course),

                _ => descending
                ? students.OrderByDescending(s => s.Id)
                : students.OrderBy(s => s.Id)
            };

            if (query.PageNumber < 1)
            {
                query.PageNumber = 1;
            }

            if (query.PageSize < 1)
            {
                query.PageSize = 10;
            }

            if (query.PageSize > 100)
            {
                query.PageSize = 100;
            }

            int skip = (query.PageNumber - 1) * query.PageSize;

            students = students.Skip(skip).Take(query.PageSize);

            List<StudentRepDTO> data = await students.Select(s => new StudentRepDTO
            {
                Id = s.Id,
                Name = s.Name,
                Age = s.Age,
                Email = s.Email,
                Course = s.Course,
                CreatedAt = s.CreatedAt
            }).ToListAsync();

            int totalPages = (int)Math.Ceiling(totalRecords / (double)query.PageSize);

            return new PagedResultDTO<StudentRepDTO>
            {
                Data = data,
                PageNumber = query.PageNumber,
                PageSize = query.PageSize,
                TotalRecords = totalRecords,
                TotalPages = totalPages
            };
        }
        public async Task<List<Student>> GetAllAsync()
        {
            return await _context.Students.AsNoTracking().ToListAsync();
        }
        public async Task<Student?> GetByIdAsync(int id)
        {
            return await _context.Students.AsNoTracking().FirstOrDefaultAsync(s => s.Id == id);
        }
        public async Task<List<Student>> AddAsync(List<Student> students)
        {
            await _context.Students.AddRangeAsync(students);

            await _context.SaveChangesAsync();

            return students;
        }
        public async Task<Student?> UpdateAsync(int id, Student student)
        {
            var existingStudent = await _context.Students.FirstOrDefaultAsync(s => s.Id == id);

            if (existingStudent == null)
            {
                return null;
            }

            existingStudent.Name = student.Name;
            existingStudent.Age = student.Age;
            existingStudent.Email = student.Email;
            existingStudent.Course = student.Course;

            await _context.SaveChangesAsync();

            return existingStudent;
        }
        public async Task<List<Student>> UpdateMultipleAsync(List<Student> students)
        {
            var studentIds = students.Select(s => s.Id).ToList();

            var existingStudents = await _context.Students.Where(
                s => studentIds.Contains(s.Id)).ToListAsync();

            foreach (var student in students)
            {
                var existingStudent = existingStudents.FirstOrDefault(s => s.Id == student.Id);

                if (existingStudent == null)
                {
                    continue;
                }

                existingStudent.Name = student.Name;
                existingStudent.Age = student.Age;
                existingStudent.Email = student.Email;
                existingStudent.Course = student.Course;
            }

            await _context.SaveChangesAsync();

            return existingStudents;
        }
        public async Task<bool> DeleteAsync(int id)
        {
            var student = await _context.Students.FirstOrDefaultAsync(s => s.Id == id);

            if (student == null)
            {
                return false;
            }

            _context.Students.Remove(student);

            await _context.SaveChangesAsync();

            return true;
        }
    }
}

Services:
IStudentService.cs:
using Swagger_DocumentationAPI.DTOs;

namespace Swagger_DocumentationAPI.Services
{
    public interface IStudentService
    {
        Task<PagedResultDTO<StudentRepDTO>> GetStudentsAsync(StudentQueryDTO query);
        Task<List<StudentRepDTO>> GetAllStudentsAsync();
        Task<StudentRepDTO?> GetStudentByIdAsync(int id);
        Task<List<StudentRepDTO>> AddStudentAsync(List<StudentDTO> students);
        Task<StudentRepDTO?> UpdateStudentAsync(int id, StudentDTO studentsDto);
        Task<List<StudentRepDTO>> UpdateStudentsAsync(List<StudentDTO> students);
        Task<bool> DeleteStudentAsync(int id);
    }
}

StudentService.cs:
using Swagger_DocumentationAPI.DTOs;
using Swagger_DocumentationAPI.Models;
using Swagger_DocumentationAPI.Repositories;

namespace Swagger_DocumentationAPI.Services
{
    public class StudentService : IStudentService
    {
        private readonly IStudentRepository _repository;
        private readonly IConfiguration _configuration;

        public StudentService(IStudentRepository repository,
            IConfiguration configuration)
        {
            _repository = repository;
            _configuration = configuration;
        }
        public async Task<PagedResultDTO<StudentRepDTO>> GetStudentsAsync(StudentQueryDTO query)
        {
            return await _repository.GetStudentsAsync(query);
        }
        public async Task<List<StudentRepDTO>> GetAllStudentsAsync()
        {
            var students = await _repository.GetAllAsync();

            return students.Select(s => new StudentRepDTO
            {
                Id = s.Id,
                Name = s.Name,
                Age = s.Age,
                Email = s.Email,
                Course = s.Course,
                CreatedAt = s.CreatedAt
            }).ToList();
        }
        public async Task<StudentRepDTO?> GetStudentByIdAsync(int id)
        {
            var student = await _repository.GetByIdAsync(id);

            if (student == null)
            {
                return null;
            }

            return new StudentRepDTO
            {
                Id = student.Id,
                Name = student.Name,
                Age = student.Age,
                Email = student.Email,
                Course = student.Course,
                CreatedAt = student.CreatedAt
            };
        }
        public async Task<List<StudentRepDTO>> AddStudentAsync(List<StudentDTO> students)
        {
            var maxStudents = _configuration.GetValue<int>("AppSettings:MaxStudents");

            if (maxStudents <= 0)
            {
                throw new InvalidOperationException(
                    "AppSettings:MaxStudents must be configured with a positive value.");
            }

            var currentStudents = await _repository.GetAllAsync();

            if (currentStudents.Count + students.Count > maxStudents)
            {
                throw new InvalidOperationException(
                    $"Maximum student limit of {maxStudents} exceeded.");
            }

            var studentEntities = students.Select(s => new Student
            {
                Name = s.Name,
                Age = s.Age,
                Email = s.Email,
                Course = s.Course,
                CreatedAt = DateTime.UtcNow
            }).ToList();

            var createdStudents = await _repository.AddAsync(studentEntities);

            return createdStudents.Select(s => new StudentRepDTO
            {
                Id = s.Id,
                Name = s.Name,
                Age = s.Age,
                Email = s.Email,
                Course = s.Course,
                CreatedAt = s.CreatedAt
            }).ToList();
        }
        public async Task<StudentRepDTO?> UpdateStudentAsync(int id, StudentDTO studentDto)
        {
            var student = new Student
            {
                Id = id,
                Name = studentDto.Name,
                Age = studentDto.Age,
                Email = studentDto.Email,
                Course = studentDto.Course
            };

            var updatedStudent = await _repository.UpdateAsync(id, student);

            if (updatedStudent == null)
            {
                return null;
            }

            return new StudentRepDTO
            {
                Id = updatedStudent.Id,
                Name = updatedStudent.Name,
                Age = updatedStudent.Age,
                Email = updatedStudent.Email,
                Course = updatedStudent.Course,
                CreatedAt = updatedStudent.CreatedAt
            };
        }
        public async Task<List<StudentRepDTO>> UpdateStudentsAsync(List<StudentDTO> students)
        {
            var studentEntities = students.Select(s => new Student
            {
                Id = s.Id,
                Name = s.Name,
                Age = s.Age,
                Email = s.Email,
                Course = s.Course
            }).ToList();

            var updatedStudents = await _repository.UpdateMultipleAsync(studentEntities);

            return updatedStudents.Select(s => new StudentRepDTO
            {
                Id = s.Id,
                Name = s.Name,
                Age = s.Age,
                Email = s.Email,
                Course = s.Course,
                CreatedAt = s.CreatedAt
            }).ToList();
        }

        public async Task<bool> DeleteStudentAsync(int id)
        {
            return await _repository.DeleteAsync(id);
        }
    }
}

Controllers:
StudentController.cs:
using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Swagger_DocumentationAPI.DTOs;
using Swagger_DocumentationAPI.Services;

namespace Swagger_DocumentationAPI.Controllers
{
    /// <summary>
    /// Provides students endpoints for API version 1 and 2.
    /// </summary>
    [ApiController]
    [ApiVersion("1.0")]
    [ApiVersion("2.0")]
    [Route("api/v{version:apiVersion}/[controller]")]
    [Authorize]
    public class StudentController : ControllerBase
    {
        private readonly ILogger<StudentController> _logger;
        private readonly IStudentService _studentService;

        //One constructor containing all dependencies
        public StudentController(
            ILogger<StudentController> logger,
            IStudentService studentService)
        {
            _logger = logger;
            _studentService = studentService;
        }

        // Version 1: existing response format
        /// <summary>
        /// Retrieves all student records using API version 1.
        /// </summary>
        /// <param name="query">Pagination, search and sorting options.</param>
        /// <returns>A list of students.</returns>
        /// <response code="200">Students retrieved successfully.</response>
        [HttpGet]
        [MapToApiVersion("1.0")]
        [Authorize(Roles = "Admin,User")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetStudents([FromQuery] StudentQueryDTO query)
        {
            _logger.LogInformation("Getting All Students using API v1");

            var result = await _studentService.GetStudentsAsync(query);

            return Ok(result);
        }

        // Version 2: existing response format
        /// <summary>
        /// Retrieves all student records using API version 2.
        /// </summary>
        /// <param name="query">Pagination, search and sorting options.</param>
        /// <returns>A list of students.</returns>
        /// <response code="200">Students retrieved successfully.</response>
        [HttpGet]
        [MapToApiVersion("2.0")]
        [Authorize(Roles = "Admin,User")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetStudentsv2([FromQuery] StudentQueryDTO query)
        {
            _logger.LogInformation("Getting All Students using API v2");

            var result = await _studentService.GetStudentsAsync(query);

            return Ok(result);
        }

        /// <summary>
        /// Retrieves a student using by ID using API v1.
        /// </summary>
        /// <param name="id">The unique student ID.</param>
        /// <returns>The requested student record.</returns>
        /// <response code="200">Student found.</response>
        /// <response code="404">Student does not exist.</response>
        /// <exception cref="KeyNotFoundException"></exception>
        [HttpGet("{id:int}")]
        [MapToApiVersion("1.0")]
        [Authorize(Roles = "Admin,User")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetStudentByIdAsync(int id)
        {
            _logger.LogInformation("Getting Students with ID: {StudentId} using API v1", id);

            var student = await _studentService.GetStudentByIdAsync(id);

            if (student == null)
            {
                throw new KeyNotFoundException($"Student with ID {id} was not found.");
            }

            return Ok(student);
        }

        /// <summary>
        /// Retrieves a student using by ID using API v2.
        /// </summary>
        /// <param name="id">The unique student ID.</param>
        /// <returns>The requested student record.</returns>
        /// <response code="200">Student found.</response>
        /// <response code="404">Student does not exist.</response>
        /// <exception cref="KeyNotFoundException"></exception>
        [HttpGet("{id:int}")]
        [MapToApiVersion("2.0")]
        [Authorize(Roles = "Admin,User")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetStudentByIdV2Async(int id)
        {
            _logger.LogInformation("Getting Students with ID: {StudentId} using API v2", id);

            var student = await _studentService.GetStudentByIdAsync(id);

            if (student == null)
            {
                throw new KeyNotFoundException($"Student with ID {id} was not found.");
            }

            return Ok(student);
        }

        /// <summary>
        /// Creates a new student records using API v1.
        /// </summary>
        /// <param name="students">Student details to create.</param>
        /// <response code="201">Student created successfully.</response>
        /// <response code="400">Invalid student data.</response>
        /// <exception cref="ArgumentException"></exception>
        [HttpPost]
        [MapToApiVersion("1.0")]
        [Authorize(Roles = "Admin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> AddStudentAsync(List<StudentDTO> students)
        {
            if (students == null || students.Count == 0)
            {
                throw new ArgumentException("Please provide at least one student.");
            }

            _logger.LogInformation("Creating {StudentCount} students using API v1.", students.Count);

            var createdStudents = await _studentService.AddStudentAsync(students);

            return StatusCode(StatusCodes.Status201Created, createdStudents);
        }

        /// <summary>
        /// Creates a new student records using API v2.
        /// </summary>
        /// <param name="students">Student details to create.</param>
        /// <response code="201">Student created successfully.</response>
        /// <response code="400">Invalid student data.</response>
        /// <exception cref="ArgumentException"></exception>
        [HttpPost]
        [MapToApiVersion("2.0")]
        [Authorize(Roles = "Admin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> AddStudentV2Async(List<StudentDTO> students)
        {
            if (students == null || students.Count == 0)
            {
                throw new ArgumentException("Please provide at least one student.");
            }

            _logger.LogInformation("Creating {StudentCount} students using API v2.", students.Count);

            var createdStudents = await _studentService.AddStudentAsync(students);

            return StatusCode(StatusCodes.Status201Created, createdStudents);
        }

        /// <summary>
        /// Updates an existing student record using API v1.
        /// </summary>
        /// <param name="id">Student ID to update.</param>
        /// <param name="studentDto"></param>
        /// <response code="200">Student updated successfully.</response>
        /// <response code="404">Student not found.</response>
        [HttpPut("{id:int}")]
        [MapToApiVersion("1.0")]
        [Authorize(Roles = "Admin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType (StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UpdateStudentAsync(int id, [FromBody] StudentDTO studentDto)
        {
            _logger.LogInformation("Updating student with ID: {StudentID} using API V1", id);

            var student = await _studentService.UpdateStudentAsync(id, studentDto);

            if (student == null)
            {
                return NotFound(new
                {
                    message = $"Student with ID {id} was not found."
                });
            }

            return Ok(student);
        }

        /// <summary>
        /// Updates an existing multiple students records using API v1.
        /// </summary>
        /// <param name="students">Students update.</param>
        /// <response code="200">Students updated successfully.</response>
        /// <response code="404">Students not found.</response>
        [HttpPut("Multiple")]
        [MapToApiVersion("1.0")]
        [Authorize(Roles = "Admin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UpdateStudentsAsync(List<StudentDTO> students)
        {
            if (students == null || students.Count == 0)
            {
                return BadRequest("Please provide atleast one student.");
            }

            _logger.LogInformation("Updating {StudentCount} students using API v1.", students.Count);

            var updatedstudents = await _studentService.UpdateStudentsAsync(students);

            if (updatedstudents.Count == 0)
            {
                return NotFound("No matching students were found.");
            }

            return Ok(updatedstudents);
        }

        /// <summary>
        /// Deletes a student using their ID using API v1.
        /// </summary>
        /// <param name="id">Student ID to delete.</param>
        /// <response code="204">Student deleted successfully.</response>
        /// <response code="404">Student not found.</response>
        [HttpDelete("{id:int}")]
        [MapToApiVersion("1.0")]
        [Authorize(Roles = "Admin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> DeleteStudentAsync(int id)
        {
            _logger.LogInformation("Deleting student with ID: {StudentId} using API v1", id);

            var deleted = await _studentService.DeleteStudentAsync(id);

            if (!deleted)
            {
                return NotFound("Student Not Found.");
            }

            return Ok("Student Deleted Successfully.");
        }
    }
}

AuthController.cs:
using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Swagger_DocumentationAPI.DTOs;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Swagger_DocumentationAPI.Controllers
{
    [ApiController]
    [ApiVersionNeutral]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<AuthController> _logger;

        public AuthController(IConfiguration configuration,
            ILogger<AuthController> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        [AllowAnonymous]
        [HttpPost("login")]
        public IActionResult Login([FromBody] LoginDTO request)
        {
            string role;

            //Demo credentials only. Replace with database-backed
            //user lookup and password-hash verification.
            if (request.Username == "admin" &&
                request.Password == "admin@123")
            {
                role = "Admin";
            }

            else if (request.Username == "user" &&
                request.Password == "user@123")
            {
                role = "User";
            }

            else
            {
                _logger.LogWarning("Failed login attempt for username {Username}", request.Username);

                return Unauthorized(new
                {
                    message = "Invalid Username or Password."
                });
            }

            var jwt = _configuration.GetSection("Jwt");

            var key = jwt["Key"]!;
            var issuer = jwt["Issuer"]!;
            var audience = jwt["Audience"]!;

            var expiryMinutes = jwt.GetValue<int>("ExpiryMinutes");

            var claims = new List<Claim>
            {
                new(ClaimTypes.Name, request.Username),
                new(ClaimTypes.Role, role),
                new(JwtRegisteredClaimNames.Jti,
                Guid.NewGuid().ToString())
            };

            var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));

            var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

            var expiresAt = DateTime.UtcNow.AddMinutes(expiryMinutes);

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                expires: expiresAt,
                signingCredentials: credentials);

            var accessToken = new JwtSecurityTokenHandler().WriteToken(token);

            _logger.LogInformation("JWT token generated for role {Role}", role);

            return Ok(new
            {
                accessToken,
                tokenType = "Bearer",
                username = request.Username,
                role,
                expiresAt,
                expiresInMinutes = expiryMinutes
            });
        }
    }
}

Program.cs:
using Asp.Versioning;
using Asp.Versioning.ApiExplorer;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc.ApiExplorer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Swagger_DocumentationAPI.Data;
using Swagger_DocumentationAPI.Middleware;
using Swagger_DocumentationAPI.Repositories;
using Swagger_DocumentationAPI.Services;
using System.Reflection;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = false;
    options.ReportApiVersions = true;

    options.ApiVersionReader = new UrlSegmentApiVersionReader();
})
    .AddMvc()
    .AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Student Management API",
        Version = "v1",
        Description = "Student Management API with JWT Authentication - Version 1"
    });

    options.SwaggerDoc("v2", new OpenApiInfo
    {
        Title = "Student Management API",
        Version = "v2",
        Description = "Student Management API with JWT Authentication - Version 2"
    });

    options.DocInclusionPredicate((documentName, apiDescription) =>
    string.Equals(apiDescription.GroupName,
    documentName,
    StringComparison.OrdinalIgnoreCase));

    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);

    options.IncludeXmlComments(xmlPath);

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter your JWT access token."
    });

    options.AddSecurityRequirement(document =>
    new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", document)] = []
    });
});

builder.Services.AddDbContext<StudentDbContext>(options =>
options.UseMySQL(
    builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException(
        "DefaultConnection connection string was not found.")));

builder.Services.AddScoped<IStudentRepository, StudentRepository>();
builder.Services.AddScoped<IStudentService, StudentService>();

//JWT Authentication
var jwt = builder.Configuration.GetSection("Jwt");

var jwtKey = jwt["Key"];
var jwtIssuer = jwt["Issuer"];
var jwtAudience = jwt["Audience"];
var expiryMinutes = jwt.GetValue<int>("ExpiryMinutes");

if (string.IsNullOrWhiteSpace(jwtKey) ||
    Encoding.UTF8.GetByteCount(jwtKey) < 32)
{
    throw new InvalidOperationException("Jwt:Key must contain a secret at least 32 bytes.");
}

if (string.IsNullOrWhiteSpace(jwtIssuer) ||
    string.IsNullOrWhiteSpace(jwtAudience) ||
    expiryMinutes <= 0)
{
    throw new InvalidOperationException(
        "Jwt:Issuer, Jwt:Audience and Jwt:ExpiryMinutes must be configured.");
}

var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;

    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,

            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = signingKey,

            RoleClaimType = System.Security.Claims.ClaimTypes.Role,

            ClockSkew = TimeSpan.Zero
        };
    });


builder.Services.AddAuthorization();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint(
            "/swagger/v1/swagger.json",
            "Student Management API v1");

        options.SwaggerEndpoint(
            "/swagger/v2/swagger.json",
            "Student Management API v2");
    });
}

app.UseHttpsRedirection();

app.UseMiddleware<ExceptionHandlingMiddleware>();

app.UseMiddleware<RequestTimeMiddleware>();

//Authentication must run before authorization.
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

appsettings.json:
{
  "AppSettings": {
    "ApplicationName": "Student Management API",
    "Version": "1.0",
    "MaxStudents": 100
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Port=3306;Database=Student_DB;User=root;Password=Srinivas@007"
  },
  "Jwt": {
    "Issuer": "StudentManagementAPI",
    "Audience": "StudentManagementClient",
    "Key": "CHANGE_THIS_TO_A_LONG_RANDOM_SECRET_KEY_123456789",
    "ExpiryMinutes": 30
  },
  "AllowedHosts": "*"
}

